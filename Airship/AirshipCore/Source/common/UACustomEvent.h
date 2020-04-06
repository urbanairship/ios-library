/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

#define kUAInteractionMCRAP @"ua_mcrap"
#define kUACustomEventCharacterLimit 255

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
 * The event's properties.
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
 */
- (void)setInteractionFromMessageCenterMessage:(NSString *)messageID;

/**
 * Sets a custom BOOL property.
 *
 * @param value The property value.
 * @param key The property key.
 * @deprecated Deprecated – to be removed in SDK version 14.0. Instead use the properties property of UACustomEvent.
 */

- (void)setBoolProperty:(BOOL)value forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use the properties property of UACustomEvent.");

/**
 * Sets a custom String property.
 *
 * @param value The property value.
 * @param key The property key.
 * @deprecated Deprecated – to be removed in SDK version 14.0. Instead use  Instead use the properties property of UACustomEvent.
 */
- (void)setStringProperty:(NSString *)value forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use the properties property of UACustomEvent.");

/**
 * Sets a custom Number property.
 *
 * @param value The property value.
 * @param key The property key.
 * @deprecated Deprecated – to be removed in SDK version 14.0. Instead use  Instead use the properties property of UACustomEvent.
 */
- (void)setNumberProperty:(NSNumber *)value forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use the properties property of UACustomEvent.");

/**
 * Adds the event to analytics.
 */
- (void)track;

/**
 * Sets a custom String array property. 
 *
 * @param value The property value.
 * @param key The property key.
 * @deprecated Deprecated – to be removed in SDK version 14.0. Instead use  Instead use the properties property of UACustomEvent.
 */
- (void)setStringArrayProperty:(NSArray<NSString *> *)value forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use the properties property of UACustomEvent.");

@end

NS_ASSUME_NONNULL_END
