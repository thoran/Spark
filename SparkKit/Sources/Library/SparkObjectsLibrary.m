//
//  SparkObjectsLibrary.m
//  Spark
//
//  Created by Fox on Fri Dec 12 2003.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//

#import <SparkKit/SparkObjectsLibrary.h>

#import <libkern/OSAtomic.h>
#import <ShadowKit/SKCFContext.h>
#import <ShadowKit/SKSerialization.h>
#import <ShadowKit/SKAppKitExtensions.h>

#import <SparkKit/SparkLibrary.h>

static NSString * const kSparkLibraryVersionKey = @"SparkVersion";
static NSString * const kSparkLibraryObjectsKey = @"SparkObjects";

NSString * const kSparkNotificationObject = @"SparkNotificationObject";

NSString* const kSparkLibraryWillAddObjectNotification = @"SparkLibraryWillAddObject";
NSString* const kSparkLibraryDidAddObjectNotification = @"SparkLibraryDidAddObject";

NSString* const kSparkLibraryWillUpdateObjectNotification = @"kSparkLibraryWillUpdateObject";
NSString* const kSparkLibraryDidUpdateObjectNotification = @"SparkLibraryDidUpdateObject";

NSString* const kSparkLibraryWillRemoveObjectNotification = @"kSparkLibraryWillRemoveObject";
NSString* const kSparkLibraryDidRemoveObjectNotification = @"SparkLibraryDidRemoveObject";

#define kSparkLibraryVersion2_0		(UInt32)0x200
static const unsigned int kSparkObjectsLibraryCurrentVersion = kSparkLibraryVersion2_0;

#pragma mark -
@implementation SparkObjectsLibrary

+ (id)objectsLibraryWithLibrary:(SparkLibrary *)aLibrary {
  return [[[self alloc] initWithLibrary:aLibrary] autorelease];
}

- (id)init {
  if (self = [self initWithLibrary:nil]) {
  }
  return self;
}

- (id)initWithLibrary:(SparkLibrary *)aLibrary {
  NSParameterAssert(aLibrary);
  if (self = [super init]) {
    [self setLibrary:aLibrary];
    sp_uid = kSparkLibraryReserved;
    sp_objects = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kSKIntDictionaryKeyCallBacks, &kSKNSObjectDictionaryValueCallBacks);
  }
  return self;
}

- (void)dealloc {
  if (sp_objects)
    CFRelease(sp_objects);
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> {Objects: %u}",
    [self class], self, [self count]];
}

#pragma mark -
- (SparkLibrary *)library {
  return sp_library;
}

- (void)setLibrary:(SparkLibrary *)aLibrary {
  sp_library = aLibrary;
}

#pragma mark -
- (UInt32)count {
  return sp_objects ? CFDictionaryGetCount(sp_objects) : 0;
}

- (NSArray *)objects {
  unsigned count = CFDictionaryGetCount(sp_objects);
  SparkLibraryObject *values[count];
  CFDictionaryGetKeysAndValues(sp_objects, NULL, (const void **)values);
  return [NSArray arrayWithObjects:values count:count];
}
- (NSEnumerator *)objectEnumerator {
  // Look like it works but not really safe with int key
  //return [(id)sp_objects objectEnumerator];
  return [[self objects] objectEnumerator];
}

- (BOOL)containsObject:(SparkLibraryObject *)object {
  return object ? CFDictionaryContainsKey(sp_objects, (void *)[object uid]) : NO;
}

- (id)objectForUID:(UInt32)uid {
  return uid ? (id)CFDictionaryGetValue(sp_objects, (void *)uid) : nil;
}

#pragma mark -
- (BOOL)addObject:(SparkLibraryObject *)object {
  NSParameterAssert(object != nil);
  @try {
    // Will add object
    if (![self containsObject:object]) {
      if (![object uid]) {
        [object setUID:[self nextUID]];
      } else if ([object uid] > sp_uid) {
        sp_uid = [object uid];
      }
      CFDictionarySetValue(sp_objects, (void *)[object uid], object);
      [object setLibrary:[self library]];
      // Did add
      return YES;
    } else { /* If object already in Library */
      [self updateObject:object];
    }
  }
  @catch (id exception) {
    SKLogException(exception);
  }
  return NO;
}
- (int)addObjectsFromArray:(NSArray *)objects {
  int count = 0;
  SparkLibraryObject *item = nil;
  NSEnumerator *items = [objects objectEnumerator];
  while (item = [items nextObject]) {
    count += ([self addObject:item]) ? 1 : 0;
  }
  return count;
}

#pragma mark -
- (BOOL)updateObject:(SparkLibraryObject *)object {
  NSParameterAssert([self containsObject:object]);
  SparkLibraryObject *old = [self objectForUID:[object uid]];
  if (old && (old != object)) {
    // Will update
    CFDictionarySetValue(sp_objects, (void *)[object uid], object);
    [object setLibrary:[self library]];
    // Did update
    return YES;
  }
  return NO;
}

#pragma mark -
- (void)removeObject:(SparkLibraryObject *)object {
  if (object && [self containsObject:object]) {
    [object retain];
    // Will remove
    [object setLibrary:nil];
    CFDictionaryRemoveValue(sp_objects, (void *)[object uid]);
    // Did remove
    [object release];
  }
}
- (void)removeObjectsInArray:(NSArray *)objects {
  SparkLibraryObject *item = nil;
  NSEnumerator *items = [objects objectEnumerator];
  while (item = [items nextObject]) {
    [self removeObject:item];
  }
}

- (NSFileWrapper *)fileWrapper:(NSError **)outError {
  NSMutableArray *objects = [[NSMutableArray alloc] init];
  NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
  [plist setObject:SKUInt(kSparkObjectsLibraryCurrentVersion) forKey:kSparkLibraryVersionKey];
  
  SparkLibraryObject *object;
  NSEnumerator *enumerator = [self objectEnumerator];
  while (object = [enumerator nextObject]) {
    NSDictionary *serialize = SKSerializeObject(object, nil);
    if (serialize && [NSPropertyListSerialization propertyList:serialize isValidForFormat:SparkLibraryFileFormat]) {
      [objects addObject:serialize];
    } else {
      DLog(@"Error while serializing object: %@", object);
    }
  }
  
  [plist setObject:objects forKey:kSparkLibraryObjectsKey];
  [objects release];
  
  NSData *data = [NSPropertyListSerialization dataFromPropertyList:plist format:SparkLibraryFileFormat errorDescription:nil];
  [plist release];
  
  return [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper error:(NSError **)outError {
  NSData *data = [fileWrapper regularFileContents];
  require(data, bail);
  
  NSDictionary *plist = [NSPropertyListSerialization propertyListFromData:data 
                                                         mutabilityOption:NSPropertyListImmutable
                                                                   format:nil errorDescription:nil];
  require(plist, bail);
  
  NSArray *objects = [plist objectForKey:kSparkLibraryObjectsKey];
  require(objects, bail);
  
  NSDictionary *serialize;
  NSEnumerator *enumerator = [objects objectEnumerator];
  while (serialize = [enumerator nextObject]) {
    OSStatus err;
    SparkLibraryObject *object = SKDeserializeObject(serialize, &err);
    /* If class not found */
    if (!object && kSKClassNotFoundError == err) {
      object = [[SparkPlaceHolder alloc] initWithSerializedValues:serialize];
      [object autorelease];
    }
    if (object) {
      [self addObject:object];
    } else {
      DLog(@"Invalid object: %@", serialize);
    }
  }
  
  return YES;
bail:
  return NO;
}

#pragma mark -
#pragma mark UID Management
- (UInt32)nextUID {
  return OSAtomicIncrement32((int32_t *)&sp_uid);
}

- (UInt32)currentUID {
  return sp_uid;
}

- (void)setCurrentUID:(UInt32)uid {
  sp_uid = uid;
}
#pragma mark -
- (void)postNotification:(NSString *)name withObject:(id)object {
  if ([self library]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:[self library]
                                                      userInfo:[NSDictionary dictionaryWithObject:object
                                                                                           forKey:kSparkNotificationObject]];
  }
}

@end

#pragma mark -
@implementation SparkPlaceHolder

static NSImage *__SparkWarningImage = nil;
+ (void)initialize {
  if ([SparkPlaceHolder class] == self) {
    __SparkWarningImage = [NSImage imageNamed:@"Warning" inBundle:SKCurrentBundle()];
  }
}

- (id)initWithName:(NSString *)name icon:(NSImage *)icon {
  if (self = [super initWithName:name icon:nil]) {
    [self setIcon:__SparkWarningImage];
  }
  return self;
}

- (id)initWithSerializedValues:(NSDictionary *)plist {
  if (self = [super initWithSerializedValues:plist]) {
    sp_plist = [plist copy];
  }
  return self;
}

- (void)dealloc {
  [sp_plist release];
  [super dealloc];
}

- (BOOL)serialize:(NSMutableDictionary *)plist {
  if (sp_plist) {
    [plist addEntriesFromDictionary:sp_plist];
    return YES;
  }
  return NO;
}


@end