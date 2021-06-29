/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UACustomEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 * A UAAccountEventTemplate represents a custom account event template for the
 * application.
 */
@interface UAAccountEventTemplate : NSObject

///---------------------------------------------------------------------------------------
/// @name Account Event Template Properties
///---------------------------------------------------------------------------------------

/**
* The event's value. The value must be between -2^31 and
* 2^31 - 1 or it will invalidate the event.
*/
@property (nonatomic, strong, nullable) NSDecimalNumber *eventValue;

/**
 * The event's transaction ID. The transaction ID's length must not exceed 255
 * characters or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *transactionID;

/**
 * The event's category.
 */
@property (nonatomic, copy, nullable) NSString *category;

/**
 * The event's user ID.
 */
@property (nonatomic, copy, nullable) NSString *userID;

/**
 * The event's type.
 */
@property (nonatomic, copy, nullable) NSString *type;

///---------------------------------------------------------------------------------------
/// @name Account Event Template Factories
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a registered account event template.
 * @returns An Account event template instance
 */
+ (instancetype)registeredTemplate;

/**
 * Factory method for creating a registered account event template with a value from a string.
 *
 * @param eventValue The value of the event as a string. The value must be a valid
 * number between -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)registeredTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a registered account event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)registeredTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a logged in account event template.
 * @returns An Account event template instance
 */
+ (instancetype)loggedInTemplate;

/**
 * Factory method for creating a logged in account event template with a value from a string.
 *
 * @param eventValue The value of the event as a string. The value must be a valid
 * number between -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)loggedInTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a logged in account event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)loggedInTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a logged out account event template.
 * @returns An Account event template instance
 */
+ (instancetype)loggedOutTemplate;

/**
 * Factory method for creating a logged out account event template with a value from a string.
 *
 * @param eventValue The value of the event as a string. The value must be a valid
 * number between -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)loggedOutTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a logged out account event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns An Account event template instance
 */
+ (instancetype)loggedOutTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Creates the custom account event.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
