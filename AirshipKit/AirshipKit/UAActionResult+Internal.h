/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAActionResult ()

/**
 * Creates an action result that indicates the arguments were rejected.
 */
+ (instancetype)rejectedArgumentsResult;

/**
 * Creates an action result that indicates the action was not found.
 */
+ (instancetype)actionNotFoundResult;


/**
 * The result value produced when running an action (can be nil).
 */
@property (nonatomic, strong, nullable) id value;

/**
 * An optional UAActionFetchResult that can be set if the action performed a background fetch.
 */
@property (nonatomic, assign) UAActionFetchResult fetchResult;

/**
 * An optional error value that can be set if the action was unable to perform its work successfully.
 */
@property (nonatomic, strong, nullable) NSError *error;

/**
 * The actions run status.
 */
@property (nonatomic, assign) UAActionStatus status;


@end

NS_ASSUME_NONNULL_END

