/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAEvent.h"
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Event when device registration occurred.
 */
@interface UADeviceRegistrationEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name Device Registration Event Internal Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UADeviceRegistrationEvent.
 *
 * @param userData The current inbox user data.
 */
+ (instancetype)event:(UAUserData *)userData;

/**
 * Factory method to create a UADeviceRegistrationEvent.
 */
+ (instancetype)event;

@end

NS_ASSUME_NONNULL_END
