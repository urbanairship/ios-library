/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppAudienceHistorian+Internal.h"

@class UATagGroupUpdate;
@class UAAttributeUpdate;
@class UARuntimeConfig;
@class UAPreferenceDataStore;
@protocol UAContactProtocol;

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
 * The default time interval to prefer local audience data over API responses.
 */
extern NSTimeInterval const UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds;

/**
 * Delegate.
 */
@protocol UAInAppAudienceManagerDelegate <NSObject>
@required

@end

/**
 * Manages tag and attributes for in-app automation.
 */
@interface UAInAppAudienceManager : NSObject

/**
 * The manager delegate.
 */
@property (nonatomic, weak) NSObject<UAInAppAudienceManagerDelegate> *delegate;

/**
 * Tag overrides.
 *
 * @return An array of tag overrides.
 */
- (NSArray<UATagGroupUpdate *> *)tagOverrides;

/**
 * Attribute overrides.
 *
 * @return Any attribute overrides.
 */
- (NSArray<UAAttributeUpdate *> *)attributeOverrides;

/**
 * UAInAppAudienceManager class factory method.
 *
 * @param config An instance of UARuntimeConfig.
 * @param dataStore A data store.
 * @param channel The channel.
 * @param contact The contact.
 * @return A manager instance.
 */
+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                          contact:(id<UAContactProtocol>)contact;
/**
 * UAInAppAudienceManager class factory method. Used for testing.
 *
 * @param dataStore A data store.
 * @param channel The channel.
 * @param contact The contact.
 * @param historian The historian.
 * @param currentTime A UADate to be used for getting the current time.
 * @return A manager instance.
 */
+ (instancetype)managerWithDataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                             contact:(id<UAContactProtocol>)contact
                           historian:(UAInAppAudienceHistorian *)historian
                         currentTime:(UADate *)currentTime;
@end

NS_ASSUME_NONNULL_END

