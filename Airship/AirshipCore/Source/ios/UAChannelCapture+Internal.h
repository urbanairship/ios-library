/* Copyright Airship and Contributors */

#import "UAChannelCapture.h"
#import "UAPushProviderDelegate.h"
#import "UAChannel.h"
#import "UADispatcher.h"

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
 * @param mainDispatcher The main dispatcher.
 * @param backgroundDispatcher The background dispatcher.
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                    pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter
                          mainDispatcher:(UADispatcher *)mainDispatcher
                    backgroundDispatcher:(UADispatcher *)backgroundDispatcher;

@end

NS_ASSUME_NONNULL_END
