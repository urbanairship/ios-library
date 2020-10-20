/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Channel Capture copies the channelId to the device clipboard after a specific number of
 * knocks (app foregrounds) within a specific timeframe. Channel Capture can be enabled
 * or disabled in Airship Config.
 */
API_UNAVAILABLE(tvos)
@interface UAChannelCapture : NSObject

///---------------------------------------------------------------------------------------
/// @name Channel Capture Management
///---------------------------------------------------------------------------------------

/**
 * Flag indicating whether channel capture is enabled. Clear to disable. Set to enable.
 * Note: Does not persist through app launches.
 */
@property (nonatomic, assign) BOOL enabled;

@end

NS_ASSUME_NONNULL_END
