/*
 *  SparkFunctions.m
 *  SparkKit
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007 Shadow Lab. All rights reserved.
 */

#import <SparkKit/SparkFunctions.h>

#import <SparkKit/SparkAlert.h>
#import <SparkKit/SparkPrivate.h>
#import <SparkKit/SparkMultipleAlerts.h>

#import <WonderBox/WonderBox.h>

#pragma mark Utilities
bool SparkEditorIsRunning(void) {
  NSRunningApplication *app = [NSRunningApplication runningApplicationsWithBundleIdentifier:kSparkEditorBundleIdentifier].firstObject;
  return app != nil;
}

bool SparkDaemonIsRunning(void) {
  NSRunningApplication *app = [NSRunningApplication runningApplicationsWithBundleIdentifier:kSparkDaemonBundleIdentifier].firstObject;
  return app != nil;
}

void SparkLaunchEditor(void) {
  switch (SparkGetCurrentContext()) {
    default:
      spx_abort("undefined context");
    case kSparkContext_Editor:
      [NSApp activateIgnoringOtherApps:NO];
      break;
    case kSparkContext_Daemon: {
      NSRunningApplication *editor = [NSRunningApplication runningApplicationsWithBundleIdentifier:kSparkEditorBundleIdentifier].firstObject;
      if (editor) {
        [editor activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        WBAESendSimpleEventToBundle(SPXNSToCFString(kSparkEditorBundleIdentifier), kCoreEventClass, kAEReopenApplication);
      } else {
#if defined(DEBUG)
        NSURL *spark = [NSURL fileURLWithPath:@"./Spark.app"];
#else
        NSURL *spark = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"../../../"];
#endif
        if ([NSThread isMainThread]) {
          [[NSWorkspace sharedWorkspace] launchApplicationAtURL:spark options:NSWorkspaceLaunchDefault configuration:@{} error:NULL];
        } else {
          dispatch_async(dispatch_get_main_queue(), ^{
            [[NSWorkspace sharedWorkspace] launchApplicationAtURL:spark options:NSWorkspaceLaunchDefault configuration:@{} error:NULL];
          });
        }
      }
    }
      break;
  }
}

SparkContext SparkGetCurrentContext(void) {
  static SparkContext ctxt = kSparkContext_Undefined;
  if (ctxt != kSparkContext_Undefined)
    return ctxt;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (kSparkContext_Undefined == ctxt) {
      CFBundleRef bundle = CFBundleGetMainBundle();
      if (bundle) {
        CFStringRef ident = CFBundleGetIdentifier(bundle);
        if (ident) {
          if (CFEqual(SPXNSToCFString(kSparkDaemonBundleIdentifier), ident)) {
            ctxt = kSparkContext_Daemon;
          } else {
            ctxt = kSparkContext_Editor;
          }
        }
      }
    }
  });
  return ctxt;
}

#pragma mark Alerts
void SparkDisplayAlerts(NSArray *items) {
  if ([items count] == 1) {
    SparkAlert *alert = [items objectAtIndex:0];
    [NSApp activateIgnoringOtherApps:YES];

    NSAlert *dialog = [[NSAlert alloc] init];
    dialog.messageText = [alert messageText];
    dialog.informativeText = [alert informativeText];

    [dialog addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, SparkKitBundle() , @"Cancel")];

    NSString *other = [alert hideSparkButton] ? nil : NSLocalizedStringFromTableInBundle(@"LAUNCH_SPARK_BUTTON", nil,
                                                                                         SparkKitBundle(), @"Open Spark Alert Button");
    [dialog addButtonWithTitle:other];
    if ([dialog runModal] == NSAlertThirdButtonReturn) {
      SparkLaunchEditor();
    }
  } else if ([items count] > 1) {
    // FIXME: should we retain the Multiple Alert Controller ?
    SparkMultipleAlerts *alerts = [[SparkMultipleAlerts alloc] initWithAlerts:items];
    [alerts showAlerts];
  }  
}

#pragma mark Notifications

static 
WBBezelItem *_SparkNotifiationSharedItem(void) {
  static WBBezelItem *_shared = nil;
  if (!_shared) {
    _shared = [[WBBezelItem alloc] initWithImage:nil];
  }
  return _shared;
}

void SparkNotificationDisplayIcon(IconRef icon, CGFloat duration) {
  NSImage *image = [[NSImage alloc] initWithIconRef:icon];
  if (image)
    SparkNotificationDisplayImage(image, duration);
}

void SparkNotificationDisplayImage(NSImage *anImage, CGFloat duration) {
  WBBezelItem *item = _SparkNotifiationSharedItem();
  [anImage setSize:CGSizeMake(128, 128)];
  item.image = anImage;
  item.duration = duration;
  item.levelBarVisible = NO;
  [item display:nil];
}

void SparkNotificationDisplayImageWithLevel(NSImage *anImage, CGFloat level, CGFloat duration) {
  WBBezelItem *item = _SparkNotifiationSharedItem();
  item.image = anImage;
  item.duration = duration;
  item.levelValue = level;
  item.levelBarVisible = YES;
  [item display:nil];
}
