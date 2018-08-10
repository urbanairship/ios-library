/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@interface UATagGroups : NSObject <NSCoding>

+ (instancetype)tagGroupsWithTags:(NSDictionary *)tags;

- (BOOL)containsAllTags:(UATagGroups *)tagGroups;

- (BOOL)containsOnlyDeviceTags;

- (UATagGroups *)overrideDeviceTags;

- (UATagGroups *)intersect:(UATagGroups *)tagGroups;

- (NSDictionary *)toJSON;

@property(nonatomic, readonly) NSDictionary *tags;

@end
