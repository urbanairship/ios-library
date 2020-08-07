/* Copyright Airship and Contributors */

#import "UAChannelCapture.h"

@class UAPreferenceDataStore;
@class UARuntimeConfig;
@class UAChannel;
@class UAAppStateTracker;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

@interface UAChannelCapture ()

///---------------------------------------------------------------------------------------
/// @name Channel Capture Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create the UAChannelCapture object.
 *
 * @param config The Airship config.
 * @param channel The channel.
 * @param dataStore The UAPreferenceDataStore instance.
 *
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                               dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create the UAChannelCapture object. Used for testing.
 *
 * @param config The Airship config.
 * @param channel The channel.
 * @param dataStore The UAPreferenceDataStore instance.
 * @param notificationCenter The notification center.
 * @param date The date.
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter
                                    date:(UADate *)date;

@end

NS_ASSUME_NONNULL_END
