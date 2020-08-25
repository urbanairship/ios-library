/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UAScheduleTrigger;

@interface UAScheduleTriggerContext : NSObject <NSSecureCoding>

//---------------------------------------------------------------------------------------
/// @name Schedule Trigger Context Properties
///---------------------------------------------------------------------------------------

/**
 * The trigger context trigger.
 */
@property(nonatomic, readonly) UAScheduleTrigger *trigger;

/**
 * The trigger context event.
 */
@property(nullable, nonatomic, readonly) id event;

///---------------------------------------------------------------------------------------
/// @name Schedule Trigger Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a trigger context.
 *
 * @param trigger The trigger.
 * @param event The event that triggered the schedule.
 * @return A schedule trigger context.
 */
+ (instancetype)triggerContextWithTrigger:(UAScheduleTrigger *)trigger
                                    event:(nullable id)event;

@end

NS_ASSUME_NONNULL_END
