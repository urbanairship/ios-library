/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"
#import "UAConfig.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when using the UATagGroupsLookupManager component.
 */
typedef NS_ENUM(NSInteger, UATagGroupsLookupManagerErrorCode) {
    /**
     * Indicates that the component is disbabled.
     */
    UATagGroupsLookupManagerErrorCodeComponentDisabled,

    /**
     * Indicates that a valid channel is required.
     */
    UATagGroupsLookupManagerErrorCodeChannelRequired,

    /**
     * Indicates that an error occurred refreshing the cache.
     */
    UATagGroupsLookupManagerErrorCodeCacheRefresh,
};

/**
 * The domain for NSErrors generated when using the UATagGroupsLookupManager component.
 */
extern NSString * const UATagGroupsLookupManagerErrorDomain;

@interface UATagGroupsLookupManager : UAComponent

+ (instancetype)lookupManagerWithConfig:(UAConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                                  cache:(UATagGroupsLookupResponseCache *)cache
                        mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;

+ (instancetype)lookupManagerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                     cache:(UATagGroupsLookupResponseCache *)cache
                           mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;

- (void)getTagGroups:(UATagGroups *)requestedTagGroups completionHandler:(void(^)(UATagGroups *tagGroups, NSError *error)) completionHandler;

@end

NS_ASSUME_NONNULL_END
