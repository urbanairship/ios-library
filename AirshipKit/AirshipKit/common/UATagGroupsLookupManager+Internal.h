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

/**
 * High level interface for performing tag group lookups.
 */
@interface UATagGroupsLookupManager : UAComponent

/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param config An instance of UAConfig.
 * @param dataStore A data store.
 * @param cache A lookup response cache.
 * @param mutationHistory The tag groups mutation history.
 */
+ (instancetype)lookupManagerWithConfig:(UAConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                                  cache:(UATagGroupsLookupResponseCache *)cache
                        mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;
/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param client A tag groups lookup API client.
 * @param dataStore A data store.
 * @param cache A lookup response cache.
 * @param mutationHistory The tag groups mutation history.
 */
+ (instancetype)lookupManagerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                     cache:(UATagGroupsLookupResponseCache *)cache
                           mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;

/**
 * Performs a tag groups lookup.
 *
 * @param requestedTagGroups The requested tag groups.
 * @param completionHandler A completion handler taking the resulting tag groups, or an error indicating a failed lookup.
 */
- (void)getTagGroups:(UATagGroups *)requestedTagGroups completionHandler:(void(^)(UATagGroups * _Nullable tagGroups, NSError *error)) completionHandler;

@end

NS_ASSUME_NONNULL_END
