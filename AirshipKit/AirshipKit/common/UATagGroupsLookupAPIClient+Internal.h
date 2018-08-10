/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"
#import "UATagGroups+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"

@interface UATagGroupsLookupAPIClient : UAAPIClient

+ (instancetype)clientWithConfig:(UAConfig *)config;

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

- (void)lookupTagGroupsWithChannelID:(NSString *)channelID
                  requestedTagGroups:(UATagGroups *)requestedTagGroups
                      cachedResponse:(UATagGroupsLookupResponse *)cachedResponse
                   completionHandler:(void (^)(UATagGroupsLookupResponse *))completionHandler;

@end
