//
//  AXSparkAction.h
//  Spark Plugins
//
//  Created by Jean-Daniel Dupas on 27/11/08.
//  Copyright 2008 Ninsight. All rights reserved.
//

#import <SparkKit/SparkKit.h>

@interface AXSparkAction : SparkAction <NSCopying>

@property(nonatomic, copy) NSString *menuTitle;
@property(nonatomic, copy) NSString *menuItemTitle;

@end
