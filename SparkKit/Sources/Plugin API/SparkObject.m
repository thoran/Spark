/*
 *  SparkObject.m
 *  SparkKit
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2006 Shadow Lab. All rights reserved.
 *
 */

#import <ShadowKit/SKFunctions.h>
#import <SparkKit/SparkObject.h>

static
NSString* const kSparkObjectUIDKey = @"SparkObjectUID";
static
NSString* const kSparkObjectNameKey = @"SparkObjectName";
static
NSString* const kSparkObjectIconKey = @"SparkObjectIcon";

@implementation SparkObject

+ (void)initialize {
  if ([SparkObject class] == self) {
    [self exposeBinding:@"name"];
    [self exposeBinding:@"icon"];
  }
}

#pragma mark -
#pragma mark NSCoding
- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeInt32:sp_uid forKey:kSparkObjectUIDKey];
  if (sp_name)
    [coder encodeObject:sp_name forKey:kSparkObjectNameKey];
  if (sp_icon)
    [coder encodeObject:[sp_icon TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1] forKey:kSparkObjectIconKey];
  return;
}

- (id)initWithCoder:(NSCoder *)coder {
  NSImage *icon = [coder decodeObjectForKey:kSparkObjectIconKey];
  NSString *name = [coder decodeObjectForKey:kSparkObjectNameKey];
  if (self = [self initWithName:name icon:icon]) {
    [self setUID:[coder decodeInt32ForKey:kSparkObjectUIDKey]];
  }
  return self;
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
  SparkObject* copy = (id)NSCopyObject(self, 0, zone);
  copy->sp_uid = sp_uid;
  copy->sp_name = [sp_name retain];
  copy->sp_icon = [sp_icon retain];
  return copy;
}

#pragma mark -
/* Compatibility */
- (NSMutableDictionary *)propertyList {
  return [NSMutableDictionary dictionary];
}
- (id)initFromPropertyList:(NSDictionary *)plist {
  NSString *name = [plist objectForKey:kSparkObjectNameKey];
  if (!name)
    name = [plist objectForKey:@"Name"];
  
  NSData *bitmap = [plist objectForKey:kSparkObjectIconKey];
  if (!bitmap)
    bitmap = [plist objectForKey:@"Icon"];
  NSImage *icon = (bitmap) ? [[NSImage alloc] initWithData:bitmap] : nil;
  
  self = [self initWithName:name icon:icon];
  [icon release];
  return self;
}

- (BOOL)serialize:(NSMutableDictionary *)plist {
  [plist setObject:SKUInt(sp_uid) forKey:kSparkObjectUIDKey];
  if (sp_name)
    [plist setObject:sp_name forKey:kSparkObjectNameKey];
  if (sp_icon) {
    [plist setObject:[sp_icon TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1] forKey:kSparkObjectIconKey];
  }
  /* Compatibility */
  if (SKInstanceImplementSelector([self class], @selector(propertyList))) {
    id dico = [self propertyList];
    if (dico) {
      [plist addEntriesFromDictionary:dico];
    }
  }
  return YES;
}

- (id)initWithSerializedValues:(NSDictionary *)plist {
  /* Compatibility */
  if (SKInstanceImplementSelector([self class], @selector(initFromPropertyList:))) {
    self = [self initFromPropertyList:plist];
  } else {
    NSString *name = [plist objectForKey:kSparkObjectNameKey];
    if (!name)
      name = [plist objectForKey:@"Name"];
    
    NSData *bitmap = [plist objectForKey:kSparkObjectIconKey];
    if (!bitmap)
      bitmap = [plist objectForKey:@"Icon"];
    NSImage *icon = (bitmap) ? [[NSImage alloc] initWithData:bitmap] : nil;
    self = [self initWithName:name icon:icon];
    [icon release];
  }
  if (self) {
    NSNumber *value = [plist objectForKey:kSparkObjectUIDKey];
    if (!value)
      value = [plist objectForKey:@"UID"];
    [self setUID:value ? [value unsignedIntValue] : 0];
  }
  return self;
}

#pragma mark -
#pragma mark Static Initializers
+ (id)object {
  return [[[self alloc] init] autorelease];
}

+ (id)objectWithName:(NSString *)name {
  return [[[self alloc] initWithName:name] autorelease];
}

+ (id)objectWithName:(NSString *)name icon:(NSImage *)icon {
  return [[[self alloc] initWithName:name icon:icon] autorelease];
}

+ (id)objectFromPropertyList:(NSDictionary *)plist {
  return [[[self alloc] initFromPropertyList:plist] autorelease];
}

#pragma mark -
#pragma mark Init & Dealloc Methods
- (id)init {
  return [self initWithName:nil icon:nil];
}

- (id)initWithName:(NSString *)name {
  return [self initWithName:name icon:nil];
}

- (id)initWithName:(NSString *)name icon:(NSImage *)icon {
  if (self = [super init]) {
    [self setName:name];
    [self setIcon:icon];
  }
  return self;
}

- (void)dealloc {
  [sp_icon release];
  [sp_name release];
  [super dealloc];
}

- (NSComparisonResult)compare:(SparkObject *)anObject {
  return [self uid] - [anObject uid];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> {uid:%u name:%@ icon:%@}",
    [self class], self,
    sp_uid, sp_name, sp_icon];
}

#pragma mark -
#pragma mark Public Methods
- (UInt32)uid {
  return sp_uid;
}
- (void)setUID:(UInt32)uid {
  sp_uid = uid;
}

- (unsigned)hash {
  return sp_uid;
}
- (BOOL)isEqual:(id)object {
  return ([object class] == [self class]) && ([object uid] == [self uid]);
}

- (BOOL)isEqualToLibraryObject:(SparkObject *)object {
  return ([object uid] == [self uid]);
}

#pragma mark -
#pragma mark Accessors
- (NSImage *)icon {
  return sp_icon;
}
- (void)setIcon:(NSImage *)icon {
  SKSetterRetain(sp_icon, icon);
}

- (NSString *)name {
  return sp_name;
}
- (void)setName:(NSString *)name {
  SKSetterCopy(sp_name, name);
}

- (SparkLibrary *)library {
  return sp_library;
}

- (void)setLibrary:(SparkLibrary *)aLibrary {
  sp_library = aLibrary;
}

@end