/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"
#import "UAConfig.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"
#import "UADate+Internal.h"

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
 * The default time interval to prefer local tag data over API responses.
 */
extern const NSTimeInterval UATagGroupsLookupManagerDefaultPreferLocalTagDataTimeSeconds;

/**
 * Tag Group Lookup Manager delegate.
 */
@protocol UATagGroupsLookupManagerDelegate <NSObject>
@required

/**
 * Called to gather all the tags to request from the look-up API.
 * @param completionHandler Completion handler that must be called with the tag groups.
 */
- (void)gatherTagGroupsWithCompletionHandler:(void(^)(UATagGroups *tagGroups))completionHandler;
@end


/**
 * High level interface for performing tag group lookups.
 */
@interface UATagGroupsLookupManager : UAComponent

/**
 * The time interval to prefer local tag data over API responses. Defaults to 10 minutes.
 */
@property (nonatomic, assign) NSTimeInterval preferLocalTagDataTime;

/**
 * The maximum age before the cache should be refreshed.
 */
@property (nonatomic, assign) NSTimeInterval cacheMaxAgeTime;

/**
 * The amount of time that can pass before cache reads are considered stale.
 */
@property (nonatomic, assign) NSTimeInterval cacheStaleReadTime;

/**
 * The tag group manager delegate.
 */
@property (nonatomic, weak) NSObject<UATagGroupsLookupManagerDelegate> *delegate;

/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param config An instance of UAConfig.
 * @param dataStore A data store.
 * @param mutationHistory The tag groups mutation history.
 */
+ (instancetype)lookupManagerWithConfig:(UAConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                        mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;
/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param client A tag groups lookup API client.
 * @param dataStore A data store.
 * @param cache A lookup response cache.
 * @param mutationHistory The tag groups mutation history.
 * @param currentTime A UADate to be used for getting the current time.
 */
+ (instancetype)lookupManagerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                     cache:(UATagGroupsLookupResponseCache *)cache
                           mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                               currentTime:(UADate *)currentTime;


/**
 * Performs a tag groups lookup.
 *
 * @param requestedTagGroups The requested tag groups.
 * @param completionHandler A completion handler taking the resulting tag groups, or an error indicating a failed lookup.
 */
- (void)getTagGroups:(UATagGroups *)requestedTagGroups completionHandler:(void(^)(UATagGroups * _Nullable tagGroups, NSError *error)) completionHandler;

@end

NS_ASSUME_NONNULL_END
