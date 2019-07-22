/* Copyright Airship and Contributors */

#import "UAChannelCapture.h"
#import "UAPushProviderDelegate.h"
#import "UAChannel.h"

@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * User channel capture enabled data store key.
 */
extern NSString *const UAChannelCaptureEnabledKey;

@interface UAChannelCapture ()

///---------------------------------------------------------------------------------------
/// @name Channel Capture Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create the UAChannelCapture.
 *
 * @param config The Airship config.
 * @param channel The channel.
 * @param pushProviderDelegate The push provider delegate.
 * @param dataStore The UAPreferenceDataStore instance.
 *
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                    pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                               dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create the UAChannelCapture. Used for testing.
 *
 * @param config The Airship config.
 * @param channel The channel.
 * @param pushProviderDelegate The push provider delegate.
 * @param dataStore The UAPreferenceDataStore instance.
 * @param notificationCenter The notification center.
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                    pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter;

@end

NS_ASSUME_NONNULL_END
