/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsLookupResponseCache+Internal.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

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
extern NSTimeInterval const UATagGroupsLookupManagerDefaultPreferLocalTagDataTimeSeconds;

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
@interface UATagGroupsLookupManager : NSObject

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
 * The tag group manager delegate.
 */
@property (nonatomic, weak) NSObject<UATagGroupsLookupManagerDelegate> *delegate;

/**
 * Performs a tag groups lookup.
 *
 * @param requestedTagGroups The requested tag groups.
 * @param completionHandler A completion handler taking the resulting tag groups, or an error indicating a failed lookup.
 */
- (void)getTagGroups:(UATagGroups *)requestedTagGroups
   completionHandler:(void(^)(UATagGroups * _Nullable tagGroups, NSError *error)) completionHandler;


/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param config An instance of UARuntimeConfig.
 * @param dataStore A data store.
 * @param tagGroupHistorian The tag groups history.
 */
+ (instancetype)lookupManagerWithConfig:(UARuntimeConfig *)config
                              dataStore:(UAPreferenceDataStore *)dataStore
                       tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian;
/**
 * UATagGroupsLookupManager class factory method.
 *
 * @param client A tag groups lookup API client.
 * @param dataStore A data store.
 * @param cache A lookup response cache.
 * @param tagGroupHistorian The tag group history.
 * @param currentTime A UADate to be used for getting the current time.
 */
+ (instancetype)lookupManagerWithAPIClient:(UATagGroupsLookupAPIClient *)client
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                     cache:(UATagGroupsLookupResponseCache *)cache
                          tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian
                               currentTime:(UADate *)currentTime;


@end

NS_ASSUME_NONNULL_END

