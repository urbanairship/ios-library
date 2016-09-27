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

#import "UAEvent.h"

@class UAInAppMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message resolution event.
 */
@interface UAInAppResolutionEvent : UAEvent

/**
 * Factory method to create an expired in-app resolution event.
 *
 * @param message The expired message.
 * @return The resolution event.
 */
+ (instancetype)expiredMessageResolutionWithMessage:(UAInAppMessage *)message;

/**
 * Factory method to create a replaced in-app resolution event.
 *
 * @param message The replaced message.
 * @param replacement The new message.
 * @return The resolution event.
 */
+ (instancetype)replacedResolutionWithMessage:(UAInAppMessage *)message
                                  replacement:(UAInAppMessage *)replacement;

/**
 * Factory method to create a button click in-app resolution event.
 *
 * @param message The message.
 * @param buttonID The clicked button ID.
 * @param buttonTitle The clicked button title.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)buttonClickedResolutionWithMessage:(UAInAppMessage *)message
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
+ (instancetype)messageClickedResolutionWithMessage:(UAInAppMessage *)message
                                    displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a dismiss in-app resolution event.
 *
 * @param message The message.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)dismissedResolutionWithMessage:(UAInAppMessage *)message
                               displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a timed out in-app resolution event.
 *
 * @param message The message.
 * @param duration How long the in-app message was displayed.
 * @return The resolution event.
 */
+ (instancetype)timedOutResolutionWithMessage:(UAInAppMessage *)message
                              displayDuration:(NSTimeInterval)duration;

/**
 * Factory method to create a direct open in-app resolution event.
 *
 * @param message The message.
 * @return The resolution event.
 */
+ (instancetype)directOpenResolutionWithMessage:(UAInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END

