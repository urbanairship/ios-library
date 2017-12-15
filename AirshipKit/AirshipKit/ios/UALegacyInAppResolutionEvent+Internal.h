/* Copyright 2017 Urban Airship and Contributors */

#import "UAEvent.h"

@class UALegacyInAppMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message resolution event.
 */
@interface UALegacyInAppResolutionEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name In App Resolution Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a replaced in-app resolution event.
 *
 * @param message The replaced message ID.
 * @param replacement The new message ID.
 * @return The resolution event.
 */
+ (instancetype)replacedResolutionWithMessageID:(NSString *)messageID
                                  replacement:(NSString *)replacementID;

/**
 * Factory method to create a direct open in-app resolution event.
 *
 * @param message The message ID.
 * @return The resolution event.
 */
+ (instancetype)directOpenResolutionWithMessageID:(NSString *)messageID;

@end

NS_ASSUME_NONNULL_END

