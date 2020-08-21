/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppAudienceHistorian+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when using the UAInAppAudienceManager component.
 */
typedef NS_ENUM(NSInteger, UAInAppAudienceManagerErrorCode) {
    /**
     * Indicates that the component is disbabled.
     */
    UAInAppAudienceManagerErrorCodeComponentDisabled,

    /**
     * Indicates that a valid channel is required.
     */
    UAInAppAudienceManagerErrorCodeChannelRequired,

    /**
     * Indicates that an error occurred refreshing the cache.
     */
    UAInAppAudienceManagerErrorCodeCacheRefresh,
};

/**
 * The domain for NSErrors generated when using the UAInAppAudienceManager component.
 */
extern NSString * const UAInAppAudienceManagerErrorDomain;

/**
 * The default time interval to prefer local tag data over API responses.
 */
extern NSTimeInterval const UAInAppAudienceManagerDefaultPreferLocalTagDataTimeSeconds;

/**
 * Delegate.
 */
@protocol UAInAppAudienceManagerDelegate <NSObject>
@required

/**
 * Called to gather all the tags to request from the look-up API.
 * @param completionHandler Completion handler that must be called with the tag groups.
 */
- (void)gatherTagGroupsWithCompletionHandler:(void(^)(UATagGroups *tagGroups))completionHandler;
@end


/**
 * Manages tag and attributes for in-app automation.
 */
@interface UAInAppAudienceManager : NSObject

/**
 * Enables/disables tag lookups.
 */
@property (nonatomic, assign) BOOL enabled;

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
 * The manager delegate.
 */
@property (nonatomic, weak) NSObject<UAInAppAudienceManagerDelegate> *delegate;

/**
 * Performs a tag groups lookup.
 *
 * @param requestedTagGroups The requested tag groups.
 * @param completionHandler A completion handler taking the resulting tag groups, or an error indicating a failed lookup.
 */
- (void)getTagGroups:(UATagGroups *)requestedTagGroups
   completionHandler:(void(^)(UATagGroups * _Nullable tagGroups, NSError *error)) completionHandler;

/**
 * Tag overrides.
 *
 * @return An array of tag overrides.
 */
- (NSArray<UATagGroupsMutation *> *)tagOverrides;

/**
 * UAInAppAudienceManager class factory method.
 *
 * @param config An instance of UARuntimeConfig.
 * @param dataStore A data store.
 * @param channel The channel.
 * @param namedUser The named user.
 * @return A manager instance.
 */
+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        namedUser:(UANamedUser *)namedUser;
/**
 * UAInAppAudienceManager class factory method. Used for testing.
 *
 * @param client A tag groups lookup API client.
 * @param dataStore A data store.
 * @param channel The channel.
 * @param namedUser The named user.
 * @param cache A lookup response cache.
 * @param historian The historian.
 * @param currentTime A UADate to be used for getting the current time.
 * @return A manager instance.
 */
+ (instancetype)managerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           namedUser:(UANamedUser *)namedUser
                               cache:(UATagGroupsLookupResponseCache *)cache
                           historian:(UAInAppAudienceHistorian *)historian
                         currentTime:(UADate *)currentTime;
@end

NS_ASSUME_NONNULL_END

