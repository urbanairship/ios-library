/* Copyright 2017 Urban Airship and Contributors */

#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Event when device registration occurred.
 */
@interface UADeviceRegistrationEvent : UAEvent

/**
 * Factory method to create a UADeviceRegistrationEvent.
 */
+ (instancetype)event;

@end

NS_ASSUME_NONNULL_END
