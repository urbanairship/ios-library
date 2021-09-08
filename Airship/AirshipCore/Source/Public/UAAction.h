/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAActionArguments;
@class UAActionResult;

NS_ASSUME_NONNULL_BEGIN

/**
 * A custom block that can be used to limit the scope of an action.
 */
typedef BOOL (^UAActionPredicate)(UAActionArguments *);

/**
 * A completion handler that signals that an action has finished executing.
 */
typedef void (^UAActionCompletionHandler)(UAActionResult *);

/**
 * A block that defines the primary work performed by an action.
 */
typedef void (^UAActionBlock)(UAActionArguments *, UAActionCompletionHandler completionHandler);

/**
 * Action protocol, which defines a modular unit of work.
 */
NS_SWIFT_NAME(Action)
@protocol UAAction <NSObject>

/**
 * Called before an action is performed to determine if the
 * the action can accept the arguments.
 *
 * This method can be used both to verify that an argument's value is an appropriate type,
 * as well as to limit the scope of execution of a desired range of values. Rejecting
 * arguments will result in the action not being performed when it is run.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @return YES if the action can perform with the arguments, otherwise NO
 */
- (BOOL)acceptsArguments:(UAActionArguments *)arguments;

/**
 * Performs the action.
 *
 * Subclasses of UAAction should override this method to define custom behavior.
 *
 * @note You should not ordinarily call this method directly. Instead, use the `UAActionRunner`.
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param completionHandler A completion handler.
 */

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler; 


@optional

/**
 * Called before the action's performWithArguments:withCompletionHandler:
 *
 * This method can be used to define optional setup or pre-execution logic.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 */
- (void)willPerformWithArguments:(UAActionArguments *)arguments;

/**
 * Called after the action has performed, before its final completion handler is called.
 *
 * This method can be used to define optional teardown or post-execution logic.
 *
 * @param arguments A UAActionArguments value representing the arguments passed to the action.
 * @param result A UAActionResult from performing the action.
 */
- (void)didPerformWithArguments:(UAActionArguments *)arguments
                     withResult:(UAActionResult *)result;


@end

NS_ASSUME_NONNULL_END
