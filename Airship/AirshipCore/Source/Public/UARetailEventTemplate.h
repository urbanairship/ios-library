/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UACustomEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 * A UARetailEventTemplate represents a custom retail event template for the
 * application.
 */

@interface UARetailEventTemplate : NSObject

///---------------------------------------------------------------------------------------
/// @name Retail Event Template Properties
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
 * The event's ID. The ID's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *identifier;

/**
 * The event's category. The category's length must not exceed 255 characters or
 * it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *category;

/**
 * The event's description. The description's length must not exceed 255 characters
 * or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *eventDescription;

/**
 * The event's brand. The brand's length must not exceed 255 characters
 * or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *brand;

/**
 * `YES` if the product is a new item, else `NO`.
 */
@property (nonatomic, assign) BOOL isNewItem;

///---------------------------------------------------------------------------------------
/// @name Retail Event Template Factories
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a browsed event template.
 * @returns A Retail event template instance
 */
+ (instancetype)browsedTemplate;

/**
 * Factory method for creating a browsed event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)browsedTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a browsed event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)browsedTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating an addedToCart event template.
 * @returns A Retail event template instance
 */
+ (instancetype)addedToCartTemplate;

/**
 * Factory method for creating an addedToCart event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)addedToCartTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating an addedToCart event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)addedToCartTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a starredProduct event template
 * @returns A Retail event template instance
 */
+ (instancetype)starredProductTemplate;

/**
 * Factory method for creating a starredProduct event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)starredProductTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a starredProduct event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)starredProductTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a purchased event template.
 * @returns A Retail event template instance
 */
+ (instancetype)purchasedTemplate;

/**
 * Factory method for creating a purchased event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)purchasedTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a purchased event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)purchasedTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a sharedProduct template event.
 * @returns A Retail event template instance
 */
+ (instancetype)sharedProductTemplate;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)sharedProductTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @returns A Retail event template instance
 */
+ (instancetype)sharedProductTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a sharedProduct event template.
 * @param source The source as an NSString.
 * @param medium The medium as an NSString
 * @returns A Retail event template instance.
 */
+ (instancetype)sharedProductTemplateWithSource:(nullable NSString *)source
                                  withMedium:(nullable NSString *)medium;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 * @param source The source as an NSString.
 * @param medium The medium as an NSString.
 * @returns A Retail event template instance
 */
+ (instancetype)sharedProductTemplateWithValueFromString:(nullable NSString *)eventValue
                                           withSource:(nullable NSString *)source
                                           withMedium:(nullable NSString *)medium;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @param source The source as an NSString.
 * @param medium The medium as an NSString.
 * @returns A Retail event template instance
 */
+ (instancetype)sharedProductTemplateWithValue:(nullable NSNumber *)eventValue
                                 withSource:(nullable NSString *)source
                                 withMedium:(nullable NSString *)medium;

/**
 * Factory method for creating a wishlist event template.
 * @returns A Retail event template instance
 */
+ (instancetype)wishlistTemplate;

/**
 * Factory method for creating a wishlist event template with a wishlist name and ID.
 *
 * @param name The name of the wishlist as as string.
 * @param wishlistID The ID of the wishlist as as string.
 * @returns A Retail event template instance
 */
+ (instancetype)wishlistTemplateWithName:(nullable NSString *)name wishlistID:(nullable NSString *)wishlistID;

/**
 * Creates the custom retail event.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
