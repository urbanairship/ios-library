/* Copyright 2017 Urban Airship and Contributors */

#import "UAEvent.h"

@class UALegacyInAppMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message resolution event.
 */
@interface UAInAppResolutionEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name In App Resolution Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an expired in-app resolution event.
 *
 * @param message The expired message.
 * @return The resolution event.
 */
+ (instancetype)expiredMessageResolutionWithMessage:(UALegacyInAppMessage *)message;

/**
 * Factory method to create a replaced in-app resolution event.
 *
 * @param message The replaced message.
 * @param replacement The new message.
 * @return The resolution event.
 */
+ (instancetype)replacedResolutionWithMessage:(UALegacyInAppMessage *)message
                                  replacement:(UALegacyInAppMessage *)replacement;

/**
 * Factory method to create a button click in-app resolution event.
 *
 * @param message The message.
 * @param buttonID The clicked button ID.
 * @param buttonTitle The clicked button title.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)buttonClickedResolutionWithMessage:(UALegacyInAppMessage *)message
                                  buttonIdentifier:(nullable NSString *)buttonID
                                       buttonTitle:(nullable NSString *)buttonTitle
                                   displayDuration:(NSTimeInterval)duration;


/**
 * Factory method to create a message click in-app resolution event.
 *
 * @param message The message.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)messageClickedResolutionWithMessage:(UALegacyInAppMessage *)message
                                    displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a dismiss in-app resolution event.
 *
 * @param message The message.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)dismissedResolutionWithMessage:(UALegacyInAppMessage *)message
                               displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a timed out in-app resolution event.
 *
 * @param message The message.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)timedOutResolutionWithMessage:(UALegacyInAppMessage *)message
                              displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a direct open in-app resolution event.
 *
 * @param message The message.
 * @return The resolution event.
 */
+ (instancetype)directOpenResolutionWithMessage:(UALegacyInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END

