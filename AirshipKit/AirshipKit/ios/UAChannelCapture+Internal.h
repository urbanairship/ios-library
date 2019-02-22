/* Copyright Urban Airship and Contributors */

#import "UAChannelCapture.h"

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
 * @param config The Urban Airship config.
 * @param push The UAPush instance.
 * @param dataStore The UAPreferenceDataStore instance.
 *
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UAConfig *)config
                                    push:(UAPush *)push
                               dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create the UAChannelCapture. Used for testing.
 *
 * @param config The Urban Airship config.
 * @param push The UAPush instance.
 * @param dataStore The UAPreferenceDataStore instance.
 * @param notificationCenter The notification center.
 * @return A channel capture instance.
 */
+ (instancetype)channelCaptureWithConfig:(UAConfig *)config
                                    push:(UAPush *)push
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter;

@end

NS_ASSUME_NONNULL_END
