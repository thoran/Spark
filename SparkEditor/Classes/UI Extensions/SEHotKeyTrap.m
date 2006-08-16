/*
 *  SEHotKeyTrap.m
 *  Spark Editor
 *
 *  Created by Grayfox on 09/07/06.
 *  Copyright 2006 Shadow Lab. All rights reserved.
 */

#import "SEHotKeyTrap.h"
#import <ShadowKit/SKCGFunctions.h>
#import <HotKeyToolKit/HotKeyToolKit.h>

/* Trap shading */
static NSImage *hk_shading = nil;
static NSDictionary *hk_style = nil; /* String style */
static NSDictionary *hk_pstyle = nil; /* Placeholder style */

static NSImage *_HKCreateShading(NSControlTint tint);

@interface SEHotKeyTrap (SEPrivate)
- (void)save;
- (void)revert;

- (BOOL)isEmpty;
- (BOOL)isTrapping;
- (void)setTrapping:(BOOL)flag;
@end

@implementation SEHotKeyTrap

/* Load default shading */
+ (void)initialize {
  // Do it once
  if (self == [SEHotKeyTrap class]) {
    hk_shading = [_HKCreateShading([NSColor currentControlTint]) retain];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeControlTint:)
                                                 name:NSControlTintDidChangeNotification
                                               object:nil];
    
    hk_style = [[NSDictionary alloc] initWithObjectsAndKeys:
      [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
      [NSColor blackColor], NSForegroundColorAttributeName,
      nil];
    
    hk_pstyle = [[NSDictionary alloc] initWithObjectsAndKeys:
      [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
      [NSColor grayColor], NSForegroundColorAttributeName,
      nil];
  }
}
/* Change default shading */
+ (void)didChangeControlTint:(NSNotification *)notif {
  [hk_shading release];
  hk_shading = [_HKCreateShading([NSColor currentControlTint]) retain];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [se_str release];
  [super dealloc];
}

/* If not a mouse down event, start to capture */
- (BOOL)acceptsFirstResponder {
  return YES;
}

- (BOOL)becomeFirstResponder {
  NSEvent *event = [NSApp currentEvent];
  /* If not a mouse down event => trap enabled. */
  /* Event is null if we are the first key view. We want to avoid trap without user interaction */
  if (event && NSLeftMouseDown != [event type]) {
    [self setTrapping:YES];
  }
  return YES;
}

- (BOOL)needsPanelToBecomeKey {
  return YES;
}

/* If was trapping, save and stop */
- (BOOL)resignFirstResponder {
  if ([self isTrapping]) {
    [self save];
    [self setTrapping:NO];
  }
  return YES;
}
/* If was trapping, save and stop */
- (void)windowDidResignKey:(NSNotification *)notification {
  if ([self isTrapping]) {
    [self save];
    [self setTrapping:NO];
  }
}

/* HotKey call back:
- First get notification info.
- Then use double tab hack to avoid dead end trap (blind could not like it).
- Save new hotKey and compute display string.
- If trap once, set trapping to false.
*/
- (void)didCatchHotKey:(NSNotification *)aNotification {
  NSDictionary *info = [aNotification userInfo];
  unsigned int nkey = [[info objectForKey:kHKEventKeyCodeKey] intValue];
  unsigned int nmodifier = [[info objectForKey:kHKEventModifierKey] intValue];
  /* Anti trap hack. If pressed tab and tab is already saved, stop recording */
  if (se_bkeycode == kVirtualTabKey && (se_bmodifier & NSDeviceIndependentModifierFlagsMask) == 0 &&
      nkey == se_bkeycode && nmodifier == se_bmodifier) {
    /* Will call -resignFirstResponder */
    [[self window] makeFirstResponder:[self nextValidKeyView]];
  } else {
    se_bkeycode = nkey;
    se_bmodifier = nmodifier;
    se_bcharacter = [[info objectForKey:kHKEventCharacterKey] intValue];
    
    [se_str release];
    se_str = [HKMapGetStringRepresentationForCharacterAndModifier(se_bcharacter, se_bmodifier) retain];
    if (se_htFlags.traponce)
      [self setTrapping:NO];
    else
      [self setNeedsDisplay:YES];
  }
}

/* Track window change to register 'catch hotkey' event and 'resign key' events */
- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
  /* window must be a trapping capable window */
  if (newWindow && ![newWindow respondsToSelector:@selector(setTrapping:)])
    [NSException raise:NSInvalidArgumentException format:@"%@ could not be used in window that does not responds to -setTrapping:", [self class]];
  
  [(id)[self window] setTrapping:NO];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[self window]];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didCatchHotKey:)
                                               name:kHKTrapWindowKeyCatchedNotification
                                             object:newWindow];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(windowDidResignKey:)
                                               name:NSWindowDidResignKeyNotification
                                             object:newWindow];
}

#pragma mark -
#pragma mark View Drawing

#define kHKTrapHeight	22
#define kHKTrapMinimumWidth		48
#define CAPS_WIDTH 19
#define LEFT_MARGIN 1.5f
#define RIGHT_MARGIN 1.5f

// Prevent from being too small
- (void)setFrameSize:(NSSize)newSize {
  NSSize correctedSize = newSize;
  correctedSize.height = kHKTrapHeight;
  if (correctedSize.width < kHKTrapMinimumWidth) correctedSize.width = kHKTrapMinimumWidth;
  
  [super setFrameSize: correctedSize];
}

- (void)setFrame:(NSRect)frameRect {
  NSRect correctedFrarme = frameRect;
  correctedFrarme.size.height = kHKTrapHeight;
  if (correctedFrarme.size.width < kHKTrapMinimumWidth) correctedFrarme.size.width = kHKTrapMinimumWidth;
  
  [super setFrame: correctedFrarme];
}

- (void)drawRect:(NSRect)frame {
  CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
  CGContextSetGrayFillColor(ctxt, 1.f, 1.f);
  
  NSRect bounds = [self bounds];
  bounds.size.height = kHKTrapHeight;
  bounds.origin.x = LEFT_MARGIN;
  bounds.size.width = NSWidth(bounds) - (LEFT_MARGIN + RIGHT_MARGIN);
  
  if ([self isTrapping]) {
    /* If trapping, round cell with 2px border and right caps with snapback icon */
    CGMutablePathRef field = CGPathCreateMutable();
    SKCGPathAddRoundRect(field, NULL, CGRectMake(NSMinX(bounds) + 2, 2, NSWidth(bounds) - CAPS_WIDTH, NSHeight(bounds) - 4), (NSHeight(bounds) - 4) / 2);
    CGMutablePathRef border = CGPathCreateMutable();
    SKCGPathAddRoundRect(border, NULL, CGRectMake(NSMinX(bounds), 0, NSWidth(bounds), NSHeight(bounds)), NSHeight(bounds) / 2);
    
    /* Draw white field */
    CGContextBeginPath(ctxt);
    CGContextAddPath(ctxt, field);
    CGContextDrawPath(ctxt, kCGPathFill);
    
    /* Save state */
    CGContextSaveGState(ctxt);
    /* Fill solid border one time with shadow */
    CGContextAddPath(ctxt, border);
    CGContextClip(ctxt);
    
    CGContextAddPath(ctxt, field);
    CGContextAddPath(ctxt, border);
    CGContextSetShadow(ctxt, CGSizeMake(0, -1.5), 1);
    CGContextDrawPath(ctxt, kCGPathEOFill);
    /* Restore state */
    CGContextRestoreGState(ctxt);
    
    /* Fill border with shading */
    CGContextSaveGState(ctxt);
    
    CGContextAddPath(ctxt, field);
    CGContextAddPath(ctxt, border);
    
    CGContextEOClip(ctxt);
    [hk_shading drawInRect:bounds fromRect:NSMakeRect(0, 0, 32, kHKTrapHeight) operation:NSCompositeSourceOver fraction:1];

    if (se_htFlags.highlight) {
      CGContextSetRGBFillColor(ctxt, 0.2, 0.2, 0.2, 0.35);
      CGContextFillRect(ctxt, CGRectFromNSRect(bounds));
    }
     
    CGContextRestoreGState(ctxt);

    CGContextSaveGState(ctxt);
    CGContextAddPath(ctxt, field);
    CGContextClip(ctxt);
    
    NSString *text = nil;
    NSDictionary *style = hk_pstyle;
    /* Draw string content */
    if (se_htFlags.hint) {
      if (se_htFlags.cancel) {
        NSString *key = HKMapGetStringRepresentationForCharacterAndModifier(se_character, se_modifier);
        text = key ? [NSString stringWithFormat:@"Revert to %@", key] : @"Cancel";
      } else {
//        if (se_character == se_bcharacter && se_modifier == se_bmodifier && se_keycode == se_bkeycode) {
//          text = @"Cancel";
//        } else {
        NSString *key = HKMapGetStringRepresentationForCharacterAndModifier(se_bcharacter, se_bmodifier);
        text = key ? [NSString stringWithFormat:@"Save %@", key] : @"Cancel";
//        }
      }
    } else if (se_str) {
      text = se_str;
      style = hk_style;
    } else {
      // draw placeholder
      text = @"Type hotkey";
    }
    float width = [text sizeWithAttributes:style].width;
    /* Should add CAPS_WIDTH to really center string, but not visually pleasant */
    [text drawAtPoint:NSMakePoint(NSMidX(bounds) - (/* CAPS_WIDTH */ + width) / 2.0, 4.5) withAttributes:style];
    
    CGContextRestoreGState(ctxt);
    CGPathRelease(border);
    CGPathRelease(field);
    
    /* Draw snap back arrow */
    CGContextSaveGState(ctxt);
    CGContextSetGrayFillColor(ctxt, 1.f, 1.f);
    
    if (se_htFlags.cancel) { /* Draw snap back arrow */
      CGContextTranslateCTM(ctxt, NSMaxX(bounds) - CAPS_WIDTH + 4.5f, 5);
    } else { /* Draw commit arrow */
      CGContextTranslateCTM(ctxt, NSMaxX(bounds) - CAPS_WIDTH + 4.5f, 17);
      CGContextScaleCTM(ctxt, 1, -1);
    }
    CGContextBeginPath(ctxt);
    CGContextMoveToPoint(ctxt, 0, 7.5);
    CGContextAddLineToPoint(ctxt, 4, 3.5);
    CGContextAddLineToPoint(ctxt, 4, 6);
    CGContextAddCurveToPoint(ctxt, 6, 6, 7, 5, 7, 4);
    CGContextAddCurveToPoint(ctxt, 7, 3, 7.5, 0.5, 2, 0);
    CGContextAddCurveToPoint(ctxt, 7, 0, 9, 1.5, 9, 5);
    CGContextAddCurveToPoint(ctxt, 9, 7.2, 7, 9, 4, 9);
    CGContextAddLineToPoint(ctxt, 4, 11.5);
    CGContextClosePath(ctxt);
    CGContextFillPath(ctxt);
    
    CGContextRestoreGState(ctxt);
  } else {
    /* Draw rounded field with 1px gray border and the delete button if needed. */
    CGContextSaveGState(ctxt);
    
    /* Draw field with light gray border */
    CGContextSetGrayStrokeColor(ctxt, 0.667, 1);
    CGContextBeginPath(ctxt);
    SKCGContextAddRoundRect(ctxt, CGRectMake(NSMinX(bounds) + 1, 1.5, NSWidth(bounds) - 2, NSHeight(bounds) - 3), (NSHeight(bounds) - 3) / 2);
    CGContextClosePath(ctxt);
    CGContextDrawPath(ctxt, kCGPathFillStroke);
    
    if (![self isEmpty]) {
      // Draw shortcut string
      float width = [se_str sizeWithAttributes:hk_style].width;
      [se_str drawAtPoint:NSMakePoint(NSMidX(bounds) - width / 2.0, 4.5) withAttributes:hk_style];
      
      if (!se_htFlags.disabled) {
        /* Draw round delete button */
        if (se_htFlags.highlight) {
          CGContextSetGrayFillColor(ctxt, 0.542, 1);
        } else {
          CGContextSetGrayFillColor(ctxt, 0.789, 1);
        }
        CGContextAddEllipseInRect(ctxt, CGRectMake(NSMaxX(bounds) - 18.5f, 4, 14, 14));
        CGContextFillPath(ctxt);
        
        float length = 3;
        CGContextTranslateCTM(ctxt, NSMaxX(bounds) - 11.5f, 11);
        
        CGContextSetLineWidth(ctxt, 1.25);
        CGContextSetGrayStrokeColor(ctxt, 1, 1);
        
        CGContextMoveToPoint(ctxt, -length, -length);
        CGContextAddLineToPoint(ctxt, length, length);
        CGContextMoveToPoint(ctxt, length, -length);
        CGContextAddLineToPoint(ctxt, -length, length);
        CGContextStrokePath(ctxt);
      }
    } else {
      // draw placeholder
      NSString *placeholder = @"click to record shortcut";
      float width = [placeholder sizeWithAttributes:hk_pstyle].width;
      [placeholder drawAtPoint:NSMakePoint(NSMidX(bounds) - width / 2.f, 4.5) withAttributes:hk_pstyle];
    }
    CGContextRestoreGState(ctxt);
  }
}

- (void)clear {
  if (!se_htFlags.trap) {
    [se_str release];
    se_str = nil;
    se_character = kHKNilUnichar;
    se_keycode = kHKInvalidVirtualKeyCode;
  }
}

- (void)keyDown:(NSEvent *)theEvent {
  /* No modifier and cancel pressed */
  if (([theEvent modifierFlags] & SEValidModifiersFlags) == 0 && [[theEvent characters] length] > 0) {
    unichar chr = [[theEvent characters] characterAtIndex:0];
    if (se_htFlags.trap) {
      switch (chr) {
        case '\e':
          [self revert];
          [self setTrapping:NO];
          return;
        case '\r':
        case 0x03:
          [self save];
          [self setTrapping:NO];
          return;
      }
    } else {
      switch (chr) {
        /* Delete */
        case 0x007f:
        case NSDeleteFunctionKey:
          [self clear];
          [self setNeedsDisplay:YES];
          return;
          /* Return or num pad enter */
        case '\r':
        case 0x03:
          [self setTrapping:YES];
          return;
      }
    }
  }
  [super keyDown:theEvent];
}

- (void)cancelOperation:(id)sender {
  ShadowTrace();
}

#pragma mark -
#pragma mark Event Handling
- (BOOL)isEmpty {
  return se_str == nil;
}

- (BOOL)isInButtonRect:(NSPoint)point {
  NSRect button = NSZeroRect;
  if ([self isTrapping]) {
    button = NSMakeRect(NSWidth([self bounds]) - CAPS_WIDTH + 4, 2, CAPS_WIDTH - 4, kHKTrapHeight - 4);    
  } else if (![self isEmpty]) {
    button = NSMakeRect(NSWidth([self bounds]) - 20, 4, 14, 14);
  }
  return [self mouse:point inRect:button];
}

- (void)save {
  se_keycode = se_bkeycode;
  se_modifier = se_bmodifier;
  se_character = se_bcharacter;
}

- (void)revert {
  [se_str release];
  se_str = [HKMapGetStringRepresentationForCharacterAndModifier(se_character, se_modifier) retain];
}

- (BOOL)isTrapping {
  return se_htFlags.trap;
}

- (void)setTrapping:(BOOL)flag {
  BOOL trap = se_htFlags.trap;
  if (!se_htFlags.disabled && XOR(flag, trap)) {
    SKSetFlag(se_htFlags.trap, flag);
    if (se_htFlags.trap) {
      NSAssert([[self window] firstResponder] == self, @"Must be first responder");
      NSPoint mouse = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
      se_htFlags.hint = [self isInButtonRect:mouse] ? 1 : 0;
      se_tracker = [self addTrackingRect:NSMakeRect(NSWidth([self bounds]) - CAPS_WIDTH + 4, 2, CAPS_WIDTH - 4, kHKTrapHeight - 4)
                                owner:self userData:nil assumeInside:se_htFlags.hint];
    } else {
      [self removeTrackingRect:se_tracker];
    }
    [self setNeedsDisplay:YES];
    [(id)[self window] setTrapping:flag];
  }
}

- (void)mouseEntered:(NSEvent *)theEvent {
  se_htFlags.hint = 1;
  [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
  se_htFlags.hint = 0;
  [self setNeedsDisplay:YES];
}

- (void)highlight:(BOOL)flag {
  BOOL highlight = se_htFlags.highlight;
  if (XOR(flag, highlight)) {
    SKSetFlag(se_htFlags.highlight, flag);
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseClick:(NSEvent *)theEvent {
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  BOOL inButton = [self isInButtonRect:mouseLoc];
  if (se_htFlags.inbutton && inButton) {
    if (![self isTrapping]) {
      [self clear];
    } else {
      /* Check if we use cancel mode */
      if (se_htFlags.cancel) {
        [self revert];
      } else {
        [self save];
      }
      [self setTrapping:NO];
    }
  } else if (!se_htFlags.inbutton && !inButton) {
    if (![self isTrapping]) {
      [self setTrapping:YES];
    } else {
      [self save];
      [self setTrapping:NO];
    }  
  }
}

- (void)mouseDown:(NSEvent *)theEvent {
  if (se_htFlags.disabled)
    return;
  
  BOOL keepOn = YES;
  BOOL isInside = YES;
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  se_htFlags.inbutton = [self isInButtonRect:mouseLoc];
  if (se_htFlags.inbutton)
    [self highlight:YES];
  
  while (keepOn) {
    theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
    mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    isInside = [self mouse:mouseLoc inRect:[self bounds]];
    
    switch ([theEvent type]) {
      case NSLeftMouseDragged:
        [self highlight:se_htFlags.inbutton && [self isInButtonRect:mouseLoc]];
        break;
      case NSLeftMouseUp:
        if (isInside) [self mouseClick:theEvent];
        [self highlight:NO];
        keepOn = NO;
        break;
      default:
        /* Ignore any other kind of event. */
        break;
    }
  };
  
  return;
}

@end

#pragma mark -
#pragma mark Shading Support
static const float const hk_aqua[] = {.300, .600, .945, 0 };
static const float const hk_aqua2[] = {.0, .320, .810, 0 };

static const float const hk_graphite[] = {.550, .600, .700, 0 };
static const float const hk_graphite2[] = {.310, .400, .510, 0 };

static const float *_shader = hk_aqua;
static const float *_shader2 = hk_aqua2;

static 
void __HKTrapShadingFunction (void *pinfo, const float *in, float *out) {
  float v;
  size_t k, components;
  SKCGShadingInfo *info = pinfo;
  components = info->components;
  
  v = *in;
  for (k = 0; k < components -1; k++)
    *out++ = MIN(_shader[k], _shader2[k]) + ABS(_shader[k] - _shader2[k]) * v;
  *out++ = 1;
}

static NSImage *_HKCreateShading(NSControlTint tint) {
  switch (tint) {
    case NSGraphiteControlTint:
      _shader = hk_graphite;
      _shader2 = hk_graphite2;
      break;
    case NSBlueControlTint:
    default:
      _shader = hk_aqua;
      _shader2 = hk_aqua2;
      break;
  }
  
  return SKCGCreateVerticalShading(32, kHKTrapHeight, __HKTrapShadingFunction, NULL);
}

@implementation SEHotKeyTrap (NSAccessibility)

- (BOOL)accessibilityIsIgnored {
  return NO;
}

- (id)accessibilityHitTest:(NSPoint)point {
  return self;
}

- (id)accessibilityFocusedUIElement {
  return self;
}

- (NSArray *)accessibilityActionNames {
  return [NSArray arrayWithObjects:NSAccessibilityConfirmAction, NSAccessibilityCancelAction, NSAccessibilityDeleteAction, nil];
}

- (NSString *)accessibilityActionDescription:(NSString *)action {
  return NSAccessibilityActionDescription(action);
}

- (void)accessibilityPerformAction:(NSString *)action {
  if ([action isEqualToString:NSAccessibilityConfirmAction]) {
    if (se_htFlags.trap) {
      [self save];
      [self setTrapping:NO];
    } else {
      [self setTrapping:YES];
    }
  } else if ([action isEqualToString:NSAccessibilityCancelAction]) {
    if (se_htFlags.trap) {
      [self revert];
      [self setTrapping:NO];
    }
  } else if ([action isEqualToString:NSAccessibilityDeleteAction]) {
    if (!se_htFlags.trap && ![self isEmpty]) {
      [self clear];
    }
  } else {
    [super accessibilityPerformAction:action];
  }
}

- (NSArray *)accessibilityAttributeNames {
  NSMutableArray *attr = [[super accessibilityAttributeNames] mutableCopy];
  if (![attr containsObject:NSAccessibilityValueAttribute])
    [attr addObject:NSAccessibilityValueAttribute];
  if (![attr containsObject:NSAccessibilitySelectedAttribute])
    [attr addObject:NSAccessibilitySelectedAttribute];
  return [attr autorelease];
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
  if ([attribute isEqualToString:NSAccessibilityRoleAttribute])
    return @"SparkHotKeyFieldRole";
  else if ([attribute isEqualToString:NSAccessibilityRoleDescriptionAttribute])
    return @"hotkey field";
  else if ([attribute isEqualToString:NSAccessibilityValueAttribute]) {
    if (se_htFlags.trap) {
      return HKMapGetSpeakableStringRepresentationForCharacterAndModifier(se_bcharacter, se_bmodifier);
    } else if (![self isEmpty]) {
      return HKMapGetSpeakableStringRepresentationForCharacterAndModifier(se_character, se_modifier);
    } else {
      return nil;
    }
  } else if ([attribute isEqualToString:NSAccessibilityHelpAttribute]) {
    if (se_htFlags.trap) 
      return @"type a keystroke combination and confirm to save it";
    else
      return @"confirm to edit keystroke combination";
  } else if ([attribute isEqualToString:NSAccessibilitySelectedAttribute]) {
    return SKBool(se_htFlags.trap);
  }
  else return [super accessibilityAttributeValue:attribute];
}

@end