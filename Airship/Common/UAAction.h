/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAActionArguments.h"

/**
 * Represents a situation in which the application was launched from a push notification.
 */
extern NSString * const UASituationLaunchedFromPush;
/**
 * Represents a situation in which a push notification was received in the foreground.
 */
extern NSString * const UASituationForegroundPush;
/**
 * Represents a situation in which a push notification was received in the background.
 */
extern NSString * const UASituationBackgroundPush;

/**
 * Represents the result of performing an action.
 */
typedef enum  {
    /**
     * The action did not result in any new data being fetched.
     */
    UAActionResultNoData,
    /**
     * The action resulted in a new data being fetched.
     */
    UAActionResultNewData,
    /**
     * The action failed.
     */
    UAActionResultFailed,
} UAActionResult;

/**
 * A custom predicate block that can be used to limit the scope of an action.
 */
typedef BOOL (^UAActionPredicate)(UAActionArguments *);
/**
 * A completion handler that singals that an action has finished executing.
 */
typedef void (^UAActionCompletionHandler)(UAActionResult);
/**
 * A block that defines the work performed by an action.
 */
typedef UAActionResult (^UAActionBlock)(UAActionArguments *, UAActionCompletionHandler);

/**
 * A unit of work that can be associated with a push notification.
 */
@interface UAAction : NSObject

/**
 * Convenience constructor for defining custom actions.
 * @param actionBlock A block representing the work performed by the action.
 */
+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock;

/**
 * Triggers the action. Subclasses of UAAction should override this method to define custom behavior.
 * @param arguments An instance of UAActionArguments.
 * @param completionHandler A UAActionCompletionHandler that will be called when the action has finished executing.
 */
- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
