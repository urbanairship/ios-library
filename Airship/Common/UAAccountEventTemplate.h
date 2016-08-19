/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
 * A UAAccountEventTemplate represents a custom account event template for the
 * application.
 */
@interface UAAccountEventTemplate : NSObject

/**
 * Factory method for creating a registered account event template.
 */
+ (instancetype)registeredTemplate;

/**
 * Factory method for creating a registered account event template with a value from a string.
 *
 * @param eventValue The value of the event as a string. The value must be a valid
 * number between -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)registeredTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a registered account event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)registeredTemplateWithValue:(nullable NSNumber *)eventValue;

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
 * The event's category. The category's length must not exceed 255 characters or
 * it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *category;

/**
 * Creates the custom account event.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
