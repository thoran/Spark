//
//  SparkLibraryPrivate.m
//  SparkKit
//
//  Created by Grayfox on 01/12/07.
//  Copyright 2007 Shadow Lab. All rights reserved.
//

#import "SparkLibraryPrivate.h"

#import <SparkKit/SparkObjectSet.h>
#import <SparkKit/SparkApplication.h>

#import <WonderBox/WBProcessFunctions.h>

#pragma mark -
#pragma mark Internal
@implementation SparkLibrary (SparkLibraryInternal)

/* convenient accessors */
- (SparkList *)listWithUID:(SparkUID)uid {
  return [sp_objects[kSparkListSet] objectWithUID:uid];
}
- (SparkEntry *)entryWithUID:(SparkUID)uid {
  return [sp_relations entryWithUID:uid];
}

- (SparkAction *)actionWithUID:(SparkUID)uid {
  return [sp_objects[kSparkActionSet] objectWithUID:uid];
}
- (SparkTrigger *)triggerWithUID:(SparkUID)uid {
  return [sp_objects[kSparkTriggerSet] objectWithUID:uid];
}
- (SparkApplication *)applicationWithUID:(SparkUID)uid {
  if (kSparkApplicationSystemUID == uid)
    return [self systemApplication];
  return [sp_objects[kSparkApplicationSet] objectWithUID:uid];
}
@end

#pragma mark Applications
@implementation SparkLibrary (SparkLibraryApplication)

- (SparkApplication *)applicationForProcess:(ProcessSerialNumber *)psn {
  NSParameterAssert(psn);
  if (kNoProcess == psn->lowLongOfPSN && kNoProcess == psn->highLongOfPSN)
    return nil;
  
  SparkApplication *result = nil;
  /* Try signature */
  OSType sign = WBProcessGetSignature(psn);
  if (sign && kUnknownType != sign) {
    SparkApplication *app;
    NSEnumerator *apps = [self applicationEnumerator];
    while (app = [apps nextObject]) {
      if ([app signature] == sign) {
        result = app;
        break;
      }
    }
  }
  /* Try bundle identifier */
  if (!result) {
    NSString *bundle = SPXCFStringBridgingRelease(WBProcessCopyBundleIdentifier(psn));
    if (bundle) {
      SparkApplication *app;
      NSEnumerator *apps = [self applicationEnumerator];
      while (app = [apps nextObject]) {
        if ([[app bundleIdentifier] isEqualToString:bundle]) {
          result = app;
          break;
        }
      }
    }
  }
  return result;
}

- (SparkApplication *)frontApplication {
  ProcessSerialNumber front;
  if (noErr == GetFrontProcess(&front))
    return [self applicationForProcess:&front];
  return nil;
}

@end

#pragma mark Archiver
@implementation SparkLibraryArchiver

@end

@implementation SparkLibraryUnarchiver

- (id)initForReadingWithData:(NSData *)data library:(SparkLibrary *)aLibrary {
  if (self = [super initForReadingWithData:data]) {
    sp_library = [aLibrary retain];
  }
  return self;
}

- (void)dealloc {
  [sp_library release];
  [super dealloc];
}

- (SparkLibrary *)library {
  return sp_library;
}

@end
