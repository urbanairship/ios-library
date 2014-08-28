/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#define kPendingPushActionDefaultsKey @"com.urbanairship.action.pending"

/**
 * Represents the possible situations.
 */
typedef NS_ENUM(NSInteger, UASituation) {
    /**
     * Represents a situation in which the action was invoked manually.
     */
    UASituationManualInvocation,

    /**
     * Represents a situation in which the application was launched from a push notification.
     */
    UASituationLaunchedFromPush,

    /**
     * Represents a situation in which a push notification was received in the foreground.
     */
    UASituationForegroundPush,

    /**
     * Represents a situation in which a push notification was received in the background.
     */
    UASituationBackgroundPush,

    /**
     * Represents a situation in which the action was triggered from a
     * web view
     */
    UASituationWebViewInvocation,

    /**
     * Represents a situation in which the action was triggered from a
     * foreground interactive notification button.
     */
    UASituationForegoundInteractiveButton,

    /**
     * Represents a situation in which the action was triggered from a
     * background interactive notification button.
     */
    UASituationBackgroundInteractiveButton
};

/**
 * Contains the arguments passed into an action during execution.
 */
@interface UAActionArguments : NSObject

/**
 * UAActionArguments factory method.
 *
 * @param value The value associated with the arguments.
 * @param situation The situation of the action.
 */
+ (instancetype)argumentsWithValue:(id)value
                     withSituation:(UASituation)situation;


/**
 * UAActionArguments factory method.
 *
 * @param value The value associated with the arguments.
 * @param situation The situation of the action.
 * @param metadata for the action - e.g. webview, payload, etc.
 */
+ (instancetype)argumentsWithValue:(id)value
                     withSituation:(UASituation)situation
                          metadata:(NSDictionary *) metadata;

/**
 * Metadata key for the web view. Available when an action is triggered from
 * a web view.
 */
extern NSString * const UAActionMetadataWebViewKey;

/**
 * Metadata key for the push notificaiton. Available when an action is triggered
 * from a push notification or user notification action.
 */
extern NSString * const UAActionMetadataPushPayloadKey;

/**
 * Metadata key for the inbox message. Available when an action is triggered from
 * a inbox message.
 */
extern NSString * const UAActionMetadataInboxMessageKey;

/**
 * Metadata key for the user notification action identifier. Available when an
 * action is triggered from a user notification action.
 */
extern NSString * const UAActionMetadataUserNotificationActionIDKey;

/**
 * Situation of the action
 */
@property (nonatomic, assign, readonly) UASituation situation;

/**
 * The value associated with the action
 */
@property (nonatomic, strong, readonly) id value;

/**
 * The argument's metadata. Metadata provides more information
 * about the environment that the action was triggered from. 
 */
@property (nonatomic, copy, readonly) NSDictionary *metadata;

@end
