/*
 *  SELibrarySource.h
 *  Spark Editor
 *
 *  Created by Jean-Daniel Dupas on 31/07/06.
 *  Copyright 2006 Adamentium. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

@class SETableView, SETriggerEntrySet;
@class SparkList, SparkApplication, SparkPlugIn;
@interface SELibrarySource : NSObject {
  IBOutlet SETableView *table;
  @private
  id se_delegate;
  NSMapTable *se_plugins;
  NSMutableArray *se_content;
}

- (IBAction)newList:(id)sender;

- (void)rearrangeObjects;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (id)objectAtIndex:(unsigned)idx;
- (SparkPlugIn *)pluginForList:(SparkList *)aList;

- (void)setTriggers:(SETriggerEntrySet *)triggers application:(SparkApplication *)anApplication;
@end

@interface NSObject (SELibrarySourceDelegate)

- (void)source:(SELibrarySource *)aSource didChangeSelection:(SparkList *)list;
- (void)source:(SELibrarySource *)aSource didAddList:(SparkList *)aList atIndex:(unsigned)anIndex;

@end