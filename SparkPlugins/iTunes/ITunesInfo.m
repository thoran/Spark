/*
 *  ITunesInfo.m
 *  Spark Plugins
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007, Shadow Lab. All rights reserved.
 */

#import "ITunesInfo.h"
#import "ITunesAction.h"
#import "ITunesStarView.h"

#import <ShadowKit/SKFunctions.h>
#import <ShadowKit/SKCGFunctions.h>
#import <ShadowKit/SKNotificationWindow.h>

#define kiTunesVisualDefaultPosition	{ -1e8, 0 }

const NSPoint kiTunesUpperLeft = kiTunesVisualDefaultPosition;
const NSPoint kiTunesUpperRight = { -2e8, 0 };
const NSPoint kiTunesBottomLeft = { -3e8, 0 };
const NSPoint kiTunesBottomRight = { -4e8, 0 };

const ITunesVisual kiTunesDefaultSettings = {
  YES, kiTunesVisualDefaultPosition, 1.5,
  { 0, 0, 0, 1 },
  /* Gray */
//  {.188, .192f, .200f, 1 },
//  {.957f, .961f, .973f, 1 },
//  {.682f, .703f, .733f, 1 },
  /* Blue */
  {.149f, .271f, .478f, 1 },
  {.961f, .969f, .988f, 1 },
  {.620f, .710f, .886f, 1 },
};

enum {
  kiTunesVisualUL,
  kiTunesVisualUR,
  kiTunesVisualBL,
  kiTunesVisualBR,
  kiTunesVisualOther,
};

SK_INLINE
int __iTunesGetTypeForLocation(NSPoint point) {
  if (SKCGFloatEquals(point.x, kiTunesUpperLeft.x))
    return kiTunesVisualUL;
  if (SKCGFloatEquals(point.x, kiTunesUpperRight.x))
    return kiTunesVisualUR;
  if (SKCGFloatEquals(point.x, kiTunesBottomLeft.x))
    return kiTunesVisualBL;
  if (SKCGFloatEquals(point.x, kiTunesBottomRight.x))
    return kiTunesVisualBR;
  
  return kiTunesVisualOther;
}
SK_INLINE
NSPoint __iTunesGetLocationForType(int type) {
  switch (type) {
    case kiTunesVisualUL:
      return kiTunesUpperLeft;
    case kiTunesVisualUR:
      return kiTunesUpperRight;
    case kiTunesVisualBL:
      return kiTunesBottomLeft;
    case kiTunesVisualBR:
      return kiTunesBottomRight;
  }
  return NSZeroPoint;
}

SK_INLINE
BOOL __FloatEquals(float a, float b) { double __delta = a - b; return (__delta < 1e-5 && __delta > -1e-5); }
SK_INLINE
BOOL __CGFloatEquals(CGFloat a, CGFloat b) { CGFloat __delta = a - b; return (__delta < 1e-5 && __delta > -1e-5); }

SK_INLINE 
void __CopyCGColor(const CGFloat cgcolor[], float color[]) {
  for (NSUInteger idx = 0; idx < 4; idx++) {
    color[idx] = (float)cgcolor[idx];
  }
}
SK_INLINE 
void __CopyColor(const float color[], CGFloat cgcolor[]) {
  for (NSUInteger idx = 0; idx < 4; idx++) {
    cgcolor[idx] = color[idx];
  }
}

SK_INLINE
BOOL __ITunesVisualCompareColors(const float c1[4], const float c2[4]) {
  for (int idx = 0; idx < 4; idx++)
    if (!__FloatEquals(c1[idx], c2[idx])) return NO;
  return YES;
}

BOOL ITunesVisualIsEqualTo(const ITunesVisual *v1, const ITunesVisual *v2) {
  if (v1->shadow != v2->shadow) return NO;
  if (!__CGFloatEquals(v1->delay, v2->delay)) return NO;
  if (!__CGFloatEquals(v1->location.x, v2->location.x) || !__CGFloatEquals(v1->location.y, v2->location.y)) return NO;
  
  if (!__ITunesVisualCompareColors(v1->text, v2->text)) return NO;
  if (!__ITunesVisualCompareColors(v1->border, v2->border)) return NO;
  if (!__ITunesVisualCompareColors(v1->backtop, v2->backtop)) return NO;
  if (!__ITunesVisualCompareColors(v1->backbot, v2->backbot)) return NO;
  
  return YES;
}

@interface ITunesInfoView : NSView {
  @private
  CGFloat border[4];
  CGShadingRef shading;
  SKSimpleShadingInfo info;
}

- (void)setVisual:(const ITunesVisual *)visual;

- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)aColor;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;

- (NSColor *)backgroundTopColor;
- (void)setBackgroundTopColor:(NSColor *)aColor;

- (NSColor *)backgroundBottomColor;
- (void)setBackgroundBottomColor:(NSColor *)aColor;

@end

@implementation ITunesInfo

+ (void)initialize {
  [NSColor setIgnoresAlpha:NO];
}

+ (ITunesInfo *)sharedWindow {
  static ITunesInfo *shared = nil;
  if (shared)
    return shared;
  else {
    @synchronized(self) {
      if (!shared) {
        shared = [[ITunesInfo alloc] init];
      }
    }
  }
  return shared;
}

- (id)init {
  NSWindow *info = [[SKNotificationWindow alloc] init];
  [info setHasShadow:YES];
  if (self = [super initWithWindow:info]) {
    [NSBundle loadNibNamed:@"iTunesInfo" owner:self];
    [self setVisual:&kiTunesDefaultSettings];
  }
  [info release];
  return self;
}

- (void)dealloc {
  [[self window] close];
  [super dealloc];
}

- (void)setIbView:(NSView *)aView {
  /* Nib root object should be release */
  [[self window] setContentSize:[aView bounds].size];
  [[self window] setContentView:[aView autorelease]];
}

#pragma mark -
SK_INLINE
void __iTunesGetColorComponents(NSColor *color, CGFloat rgba[]) {
  color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
}

- (void)getVisual:(ITunesVisual *)visual {
  bzero(visual, sizeof(*visual));
  /* Get delay */
  visual->delay = [self delay];
  /* Get location */
  if (ia_loc != kiTunesVisualOther) visual->location = __iTunesGetLocationForType(ia_loc);
  else visual->location = [[self window] frame].origin;
  /* Get shadow */
  visual->shadow = [[self window] hasShadow];
  /* Get text color */
  CGFloat rgba[4];
  __iTunesGetColorComponents([self textColor], rgba);
  __CopyCGColor(rgba, visual->text);
  [(id)[[self window] contentView] getVisual:visual];
}

- (void)setVisual:(const ITunesVisual *)visual {
  [self setDelay:visual->delay];
  [self setPosition:visual->location];
  [self setHasShadow:visual->shadow];
  [self setTextColor:[NSColor colorWithCalibratedRed:visual->text[0] green:visual->text[1] blue:visual->text[2] alpha:visual->text[3]]];
  [[[self window] contentView] setVisual:visual];
}

- (NSTimeInterval)delay {
  return [(id)[self window] delay];
}
- (void)setDelay:(NSTimeInterval)aDelay {
  [(id)[self window] setDelay:aDelay];
}

#define SCREEN_MARGIN 17
- (void)setPosition:(NSPoint)aPoint {
  NSPoint origin = aPoint;
  NSRect bounds = [[self window] frame];
  NSRect screen = [[NSScreen mainScreen] frame];
  ia_loc = __iTunesGetTypeForLocation(aPoint);
  switch (ia_loc) {
    case kiTunesVisualUL:
      origin.x = SCREEN_MARGIN * SKScreenScaleFactor([NSScreen mainScreen]);
      origin.y = NSHeight(screen) - NSHeight(bounds) - (SCREEN_MARGIN + 22) * SKScreenScaleFactor([NSScreen mainScreen]); // menu bar
      break;
    case kiTunesVisualUR:
      origin.x = NSWidth(screen) - NSWidth(bounds) - SCREEN_MARGIN * SKScreenScaleFactor([NSScreen mainScreen]);
      origin.y = NSHeight(screen) - NSHeight(bounds) - (SCREEN_MARGIN + 22) * SKScreenScaleFactor([NSScreen mainScreen]);
      break;
    case kiTunesVisualBL:
      origin.x = SCREEN_MARGIN * SKScreenScaleFactor([NSScreen mainScreen]);
      origin.y = (SCREEN_MARGIN + 22) * SKScreenScaleFactor([NSScreen mainScreen]);
      break;
    case kiTunesVisualBR:
      origin.x = NSWidth(screen) - NSWidth(bounds) - SCREEN_MARGIN * SKScreenScaleFactor([NSScreen mainScreen]);
      origin.y = (SCREEN_MARGIN + 22) * SKScreenScaleFactor([NSScreen mainScreen]);
      break;
  }
  [[self window] setFrameOrigin:origin];
}

- (void)setHasShadow:(BOOL)hasShadow {
  [[self window] setHasShadow:hasShadow];
}

- (IBAction)display:(id)sender {
  [(id)[self window] display:sender];
}

- (void)setDuration:(SInt32)aTime rate:(SInt32)rate {
  NSString *str = nil;
  SInt32 days = aTime / (3600 * 24);
  SInt32 hours = (aTime % (3600 * 24)) / 3600;
  SInt32 minutes = (aTime % 3600) / 60;
  SInt32 seconds = aTime % 60;
  
  if (days > 0) {
    str = [NSString stringWithFormat:@"%i:%.2i:%.2i:%.2i - ", days, hours, minutes, seconds];
  } else if (hours > 0) {
    str = [NSString stringWithFormat:@"%i:%.2i:%.2i -", hours, minutes, seconds];
  } else if (minutes > 0 || seconds > 0) {
    str = [NSString stringWithFormat:@"%i:%.2i -", minutes, seconds];
  } else {
    str = @" -";
  }
  [ibTime setStringValue:str];
  /* adjust time size and move rate */
  [ibTime sizeToFit];
  NSPoint origin = [ibRate frame].origin;
  origin.x = NSMaxX([ibTime frame]);
  [ibRate setFrameOrigin:origin];
  
  [ibRate setRate:lround(rate / 10.)];
}

- (void)setTrack:(iTunesTrack *)track {
  CFStringRef value = NULL;
  /* Track Name */
  if (track)
    iTunesCopyTrackStringProperty(track, kiTunesNameKey, &value);
  if (value) {
    [ibName setStringValue:(id)value];
    CFRelease(value);
    value = NULL;
  } else {
    [ibName setStringValue:NSLocalizedStringFromTableInBundle(@"<untiled>", nil, kiTunesActionBundle, @"Untitled track info")];
  }
  
  /* Album */
  if (track)
    iTunesCopyTrackStringProperty(track, kiTunesAlbumKey, &value);
  if (value) {
    [ibAlbum setStringValue:(id)value];
    CFRelease(value);
    value = NULL;
  } else {
    [ibAlbum setStringValue:@""];
  }
  
  /* Artist */
  if (track)
    iTunesCopyTrackStringProperty(track, kiTunesArtistKey, &value);
  if (value) {
    [ibArtist setStringValue:(id)value];
    CFRelease(value);
    value = NULL;
  } else {
    [ibArtist setStringValue:@""];
  }
  
  /* Time and rate */
  SInt32 duration = 0, rate = 0;
  if (track) {
    iTunesGetTrackIntegerProperty(track, kiTunesDurationKey, &duration);
    iTunesGetTrackIntegerProperty(track, kiTunesRateKey, &rate);
  }
  [self setDuration:duration rate:rate];
}

- (void)setOrigin:(NSPoint)origin {
  [[self window] setFrameOrigin:origin];
}

- (NSColor *)textColor {
  return [ibName textColor];
}

- (void)setTextColor:(NSColor *)aColor {
  [ibName setTextColor:aColor];
  [ibAlbum setTextColor:aColor];
  [ibArtist setTextColor:aColor];
  
  [ibTime setTextColor:aColor];
  [ibRate setStarsColor:aColor];
}

- (NSColor *)borderColor {
  return [(id)[[self window] contentView] borderColor];
}
- (void)setBorderColor:(NSColor *)aColor {
  [(id)[[self window] contentView] setBorderColor:aColor];
}

- (NSColor *)backgroundColor {
  return [(id)[[self window] contentView] backgroundColor];
}
- (void)setBackgroundColor:(NSColor *)aColor {
  [(id)[[self window] contentView] setBackgroundColor:aColor];
}

- (NSColor *)backgroundTopColor {
  return [(id)[[self window] contentView] backgroundTopColor];
}
- (void)setBackgroundTopColor:(NSColor *)aColor {
  [(id)[[self window] contentView] setBackgroundTopColor:aColor];
}

- (NSColor *)backgroundBottomColor {
  return [(id)[[self window] contentView] backgroundBottomColor];
}
- (void)setBackgroundBottomColor:(NSColor *)aColor {
  [(id)[[self window] contentView] setBackgroundBottomColor:aColor];
}
@end

@implementation ITunesInfoView

- (id)initWithFrame:(NSRect)frame {
  if (self = [super initWithFrame:frame]) {
    [self setVisual:&kiTunesDefaultSettings];
  }
  return self;
}

- (void)dealloc {
  if (shading)
    CGShadingRelease(shading);
  [super dealloc];
}

- (void)clearShading {
  if (shading) {
    CGShadingRelease(shading);
    shading = NULL;
  }
  [self setNeedsDisplay:YES];
}

static
void iTunesShadingFunction(void *pinfo, const CGFloat *in, CGFloat *out) {
  CGFloat v;
  SKSimpleShadingInfo *ctxt = pinfo;

  v = *in;
  for (int k = 0; k < 4; k++) {
    *out++ = ctxt->start[k] - (ctxt->start[k] - ctxt->end[k]) * pow(sin(M_PI_2 * v), 2);
  }
}

- (void)drawRect:(NSRect)aRect {
  CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
  
  CGRect rect = CGRectFromNSRect([self bounds]);
  
  CGRect internal = rect;
  internal.origin.x += 2;
  internal.origin.y += 2;
  internal.size.width -= 4;
  internal.size.height -= 4;
  SKCGContextAddRoundRect(ctxt, internal, 6);
  
  CGContextSaveGState(ctxt);
  CGContextClip(ctxt);
  if (!shading)
    shading = SKCGCreateShading(CGPointMake(0, NSHeight([self bounds])), CGPointZero, iTunesShadingFunction, &info);
  CGContextDrawShading(ctxt, shading);
  CGContextRestoreGState(ctxt);
  
  /* Border */
  SKCGContextAddRoundRect(ctxt, rect, 8);
  rect.origin.x += 3;
  rect.origin.y += 3;
  rect.size.width -= 6;
  rect.size.height -= 6;
  SKCGContextAddRoundRect(ctxt, rect, 5);
  CGContextSetRGBFillColor(ctxt, border[0], border[1], border[2], border[3]);
  CGContextDrawPath(ctxt, kCGPathEOFill);
}

#pragma mark -
- (void)getVisual:(ITunesVisual *)visual {
  __CopyCGColor(border, visual->border);
  memcpy(visual->backbot, info.end, sizeof(visual->backbot));
  memcpy(visual->backtop, info.start, sizeof(visual->backtop));
}

- (void)setVisual:(const ITunesVisual *)visual {
  __CopyColor(visual->border, border);  
  memcpy(info.end, visual->backbot, sizeof(visual->backbot));
  memcpy(info.start, visual->backtop, sizeof(visual->backtop));
  [self clearShading];
}

- (NSColor *)borderColor {
  return [NSColor colorWithCalibratedRed:border[0] green:border[1] blue:border[2] alpha:border[3]];
}

- (void)setBorderColor:(NSColor *)aColor {
  __iTunesGetColorComponents(aColor, border);
  [self setNeedsDisplay:YES];
}
- (NSColor *)backgroundColor {
  return [NSColor colorWithCalibratedRed:info.end[0] green:info.end[1] blue:info.end[2] alpha:info.end[3]];
}
- (void)setBackgroundColor:(NSColor *)aColor {
  __iTunesGetColorComponents(aColor, info.end);
  info.start[0] = 0.75 + info.end[0] * 0.25;
  info.start[1] = 0.75 + info.end[1] * 0.25;
  info.start[2] = 0.75 + info.end[2] * 0.25;
  info.start[3] = 0.75 + info.end[3] * 0.25;
  [self clearShading];
}

- (NSColor *)backgroundTopColor {
  return [NSColor colorWithCalibratedRed:info.start[0] green:info.start[1] blue:info.start[2] alpha:info.start[3]];
}
- (void)setBackgroundTopColor:(NSColor *)aColor {
  __iTunesGetColorComponents(aColor, info.start);
  [self clearShading];
}

- (NSColor *)backgroundBottomColor {
  return [NSColor colorWithCalibratedRed:info.end[0] green:info.end[1] blue:info.end[2] alpha:info.end[3]];
}
- (void)setBackgroundBottomColor:(NSColor *)aColor {
  __iTunesGetColorComponents(aColor, info.end);
  [self clearShading];
}

@end
