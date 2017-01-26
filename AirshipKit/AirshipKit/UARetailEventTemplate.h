/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "UACustomEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A UARetailEventTemplate represents a custom retail event template for the
 * application.
 */

@interface UARetailEventTemplate : NSObject

/**
 * Factory method for creating a browsed event template.
 */
+ (instancetype)browsedTemplate;

/**
 * Factory method for creating a browsed event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)browsedTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a browsed event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)browsedTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating an addedToCart event template.
 */
+ (instancetype)addedToCartTemplate;

/**
 * Factory method for creating an addedToCart event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)addedToCartTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating an addedToCart event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)addedToCartTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a starredProduct event template
 */
+ (instancetype)starredProductTemplate;

/**
 * Factory method for creating a starredProduct event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)starredProductTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a starredProduct event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)starredProductTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a purchased event template.
 */
+ (instancetype)purchasedTemplate;

/**
 * Factory method for creating a purchased event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)purchasedTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a purchased event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)purchasedTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a sharedProduct template event.
 */
+ (instancetype)sharedProductTemplate;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)sharedProductTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a sharedProduct event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)sharedProductTemplateWithValue:(nullable NSNumber *)eventValue;

/**
 * Factory method for creating a sharedProduct event template.
 * @param source The source as an NSString.
 * @param medium The medium as an NSString.
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
 */
+ (instancetype)sharedProductTemplateWithValue:(nullable NSNumber *)eventValue
                                 withSource:(nullable NSString *)source
                                 withMedium:(nullable NSString *)medium;

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

/**
 * Creates the custom retail event.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
