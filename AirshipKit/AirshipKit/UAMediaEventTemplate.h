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
 * A UAMediaEventTemplate represents a custom media event template for the
 * application.
 */
@interface UAMediaEventTemplate : NSObject

/**
 * Factory method for creating a browsed content event template.
 */
+ (instancetype)browsedTemplate;

/**
 * Factory method for creating a starred content event template.
 */
+ (instancetype)starredTemplate;

/**
 * Factory method for creating a shared content event template.
 */
+ (instancetype)sharedTemplate;

/**
 * Factory method for creating a shared content event template.
 * If the source or medium exceeds 255 characters it will cause the event to be invalid.
 *
 * @param source The source as an NSString.
 * @param medium The medium as an NSString.
 */
+ (instancetype)sharedTemplateWithSource:(nullable NSString *)source withMedium:(nullable NSString *)medium;

/**
 * Factory method for creating a consumed content event template.
 */
+ (instancetype)consumedTemplate;

/**
 * Factory method for creating a consumed content event template with a value.
 *
 * @param eventValue The value of the event as as string. The value must be between
 * -2^31 and 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)consumedTemplateWithValueFromString:(nullable NSString *)eventValue;

/**
 * Factory method for creating a consumed content event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 */
+ (instancetype)consumedTemplateWithValue:(nullable NSNumber *)eventValue;

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
 * The event's type. The type's length must not exceed 255 characters or it will
 * invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *type;

/**
 * The event's description. The description's length must not exceed 255 characters
 * or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *eventDescription;

/**
 * `YES` if the event is a feature, else `NO`.
 */
@property (nonatomic, assign) BOOL isFeature;

/**
 * The event's author. The author's length must not exceed 255 characters
 * or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *author;

/**
 * The event's publishedDate. The publishedDate's length must not exceed 255 characters
 * or it will invalidate the event.
 */
@property (nonatomic, copy, nullable) NSString *publishedDate;

/**
 * Creates the custom media event.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
