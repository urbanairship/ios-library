
#import <Foundation/Foundation.h>
#import "UATagGroupsLookupResponse+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * The default max age time.
 */
extern NSTimeInterval const UATagGroupsLookupResponseCacheDefaultMaxAgeTimeSeconds;

/**
 * The default stale read time.
 */
extern NSTimeInterval const UATagGroupsLookupResponseCacheDefaultStaleReadTimeSeconds;

/**
 * A persistent cache for tag group lookup responses.
 */
@interface UATagGroupsLookupResponseCache : NSObject

/**
 * The response.
 */
@property (nonatomic, strong, nullable) UATagGroupsLookupResponse *response;

/**
 * The previously requested tag groups.
 */
@property (nonatomic, strong, nullable) UATagGroups *requestedTagGroups;

/**
 * The date the cache was last refreshed.
 */
@property (nonatomic, readonly, nullable) NSDate *refreshDate;

/**
 * The maximum age before the cache should be refreshed.
 */
@property (nonatomic, assign) NSTimeInterval maxAgeTime;

/**
 * The amount of time that can pass before reads are considered stale.
 */
@property (nonatomic, assign) NSTimeInterval staleReadTime;

/**
 * UATagGroupsLookupResponseCache class factory method.
 *
 * @param dataStore A data store.
 */
+ (instancetype)cacheWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Indicates whether a refresh is required.
 *
 * @return `YES` if a refresh is required, `NO` otherwise.
 */
- (BOOL)needsRefresh;

/**
 * Indicates whether the cache is stale.
 *
 * @return `YES` if the cache is stale, `NO` otherwise.
 */
- (BOOL)isStale;

@end

NS_ASSUME_NONNULL_END
