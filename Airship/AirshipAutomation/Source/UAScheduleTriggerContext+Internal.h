/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAScheduleTriggerContext ()

///---------------------------------------------------------------------------------------
/// @name Schedule Trigger Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The trigger context trigger.
 */
@property(nonatomic, strong) UAScheduleTrigger *trigger;

/**
 * The trigger context event.
 */
@property(nonatomic, strong) NSDictionary *event;

@end

NS_ASSUME_NONNULL_END
