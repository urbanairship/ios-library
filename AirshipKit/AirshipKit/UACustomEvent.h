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

@class UAInboxMessage;


/**
 * A UACustomEvent captures information regarding a custom event for
 * UAAnalytics.
 */
@interface UACustomEvent : UAEvent

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
@property (nonatomic, copy, readonly) NSDictionary *properties;

/**
 * Sets the custom event's interaction type and ID from a UAInboxMessage.
 * @param message The UAInboxMessage to set the custom event's interaction type
 * and ID from.
 */
- (void)setInteractionFromMessage:(UAInboxMessage *)message;

/**
 * Sets a custom BOOL property.
 *
 * @param value The property value.
 * @param key The property key.
 */
- (void)setBoolProperty:(BOOL)value forKey:(NSString *)key;

/**
 * Sets a custom String property. The value's length must not exceed 255 characters
 * or it will invalidate the event.
 *
 * @param value The property value.
 * @param key The property key.
 */
- (void)setStringProperty:(NSString *)value forKey:(NSString *)key;

/**
 * Sets a custom Number property.
 *
 * @param value The property value.
 * @param key The property key.
 */
- (void)setNumberProperty:(NSNumber *)value forKey:(NSString *)key;

/**
 * Adds the event to analytics.
 */
- (void)track;

/**
 * Sets a custom String array property. The array must not exceed 20 entries and
 * each entry's length must not exceed 255 characters or it will invalidate the event.
 *
 * @param value The property value.
 * @param key The property key.
 */
- (void)setStringArrayProperty:(NSArray<NSString *> *)value forKey:(NSString *)key;



@end

NS_ASSUME_NONNULL_END
