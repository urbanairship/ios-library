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

/**
 * Represents the result of performing a background fetch, or none if no fetch was performed.
 */
typedef NS_OPTIONS(NSInteger, UAActionFetchResult) {
    /**
     * The action did not result in any new data being fetched.
     */
    UAActionFetchResultNoData = UIBackgroundFetchResultNoData,

    /**
     * The action resulted in new data being fetched.
     */
    UAActionFetchResultNewData = UIBackgroundFetchResultNewData,

    /**
     * The action failed.
     */
    UAActionFetchResultFailed = UIBackgroundFetchResultFailed
};

/**
 * Represents the action status.
 */
typedef NS_ENUM(NSInteger, UAActionStatus) {
    /**
     * The action accepted the arguments and executed without an error.
     */
    UAActionStatusCompleted,

    /**
     * The action was not performed because the arguments were rejected by
     * either the predicate in the registry or the action.
     */
    UAActionStatusArgumentsRejected,

    /**
     * The action was not performed because the action was not found
     * in the registry. This value is only possible if trying to run an
     * action by name through the runner.
     */
    UAActionStatusActionNotFound,

    /**
     * The action encountered an error during execution.
     */
    UAActionStatusError
};

/**
 * A class that holds the results of running an action, with optional metadata.
 */
@interface UAActionResult : NSObject

/**
 * The result value produced when running an action (can be nil).
 */
@property (nonatomic, strong, readonly) id value;

/**
 * An optional UAActionFetchResult that can be set if the action performed a background fetch.
 */
@property (nonatomic, assign, readonly) UAActionFetchResult fetchResult;

/**
 * An optional error value that can be set if the action was unable to perform its work successfully.
 */
@property (nonatomic, strong, readonly) NSError *error;

/**
 * The action's run status.
 */
@property (nonatomic, assign, readonly) UAActionStatus status;

/**
 * Creates a UAActionResult with the supplied value. The `fetchResult` and `error` properties
 * default to UAActionFetchResultNone and nil, respectively.
 *
 * @param value An id typed value object.
 * @return An instance of UAActionResult.
 */
+ (instancetype)resultWithValue:(id)value;

/**
 * Creates a UAActionResult with the supplied value and fetch result. The `error` property
 * defaults to nil.
 *
 * @param result An id typed value object.
 * @param fetchResult A UAActionFetchResult enum value.
 * @return An instance of UAActionResult.
 */
+ (instancetype)resultWithValue:(id)result withFetchResult:(UAActionFetchResult)fetchResult;

/**
 * Creates an "empty" UAActionResult with the value, fetch result and error set to
 * nil, UAActionFetchResultNone, and nil, respectively.
 */
+ (instancetype)emptyResult;

/**
 * Creates a UAActionResult with the value and fetch result set to
 * nil and UAActionFetchResultNone, respectively. The `error` property
 * is set to the supplied argument.
 *
 * @param error An instance of NSError.
 */
+ (instancetype)resultWithError:(NSError *)error;

/**
 * Creates a UAActionResult with the value set to nil. The `error`
 * and `fetchResult` properties are set to the supplied arguments.
 *
 * @param error An instance of NSError.
 * @param fetchResult A UAActionFetchResult enum value.
 */
+ (instancetype)resultWithError:(NSError *)error withFetchResult:(UAActionFetchResult)fetchResult;


@end
