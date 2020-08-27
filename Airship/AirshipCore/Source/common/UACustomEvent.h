/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The max character limit for Strings.
 */
extern const NSUInteger UACustomEventCharacterLimit;

/**
 * The max number of properties.
 */
extern const NSUInteger UACustomEventMaxPropertiesCount;

extern NSString *const UACustomEventNameKey;
extern NSString *const UACustomEventValueKey;
extern NSString *const UACustomEventPropertiesKey;
extern NSString *const UACustomEventTransactionIDKey;
extern NSString *const UACustomEventInteractionIDKey;
extern NSString *const UACustomEventInteractionTypeKey;

/**
 * A UACustomEvent captures information regarding a custom event for
 * UAAnalytics.
 */
@interface UACustomEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name Custom Event Properties
///---------------------------------------------------------------------------------------

/**
 * The event's value. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
@property (nonatomic, strong, nullable) NSDecimalNumber *eventValue;

/**
 * The event's name. The name's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy) NSString *eventName;

/**
 * The event's interaction ID. The ID's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *interactionID;

/**
 * The event's interaction type. The type's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *interactionType;

/**
 * The event's transaction ID. The ID's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *transactionID;

/**
 * The event's properties. Properties must be valid JSON:
 * - All objects are NSString, NSNumber, NSArray, NSDictionary, or NSNull
 * - All dictionary keys are NSStrings
 * - NSNumbers are not NaN or infinity
 */
@property (nonatomic, copy) NSDictionary *properties;

/**
 * The event's JSON payload.
 */
@property (nonatomic, readonly) NSDictionary *payload;

///---------------------------------------------------------------------------------------
/// @name Custom Event Factories
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a custom event.
 *
 * @param eventName The name of the event. The event's name must not exceed
 * 255 characters or it will invalidate the event.
 */
+ (instancetype)eventWithName:(NSString *)eventName;

/**
 * Factory method for creating a custom event with a value from a string.
 *
 * @param eventName The name of the event. The event's name must not exceed
 * 255 characters or it will invalidate the event.
 * @param eventValue The value of the event as a string. The value must be a valid
 * number between -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)eventWithName:(NSString *)eventName valueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a custom event with a value.
 *
 * @param eventName The name of the event. The event's name must not exceed
 * 255 characters or it will invalidate the event.
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)eventWithName:(NSString *)eventName value:(nullable NSNumber *)eventValue;

///---------------------------------------------------------------------------------------
/// @name Custom Event Management
///---------------------------------------------------------------------------------------

/**
 * Sets the custom event's interaction type and identifier as coming from a Message Center message.
 * @param messageID The message ID.
 * @note For internal use only. :nodoc:
 */
- (void)setInteractionFromMessageCenterMessage:(NSString *)messageID;

/**
 * Adds the event to analytics.
 */
- (void)track;

@end

NS_ASSUME_NONNULL_END
