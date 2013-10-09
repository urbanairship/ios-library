
#import "UAAction.h"
#import "UAPushActionArguments.h"
#import "UAActionResult.h"



typedef void (^UAActionPushCompletionHandler)(UAActionResult *);
/**
 * A block that defines the work performed by an action.
 */
typedef void (^UAPushActionBlock)(UAPushActionArguments *, UAActionPushCompletionHandler);

@interface UAPushAction : UAAction

+ (instancetype)pushActionWithBlock:(UAPushActionBlock)actionBlock;

/**
 * Triggers the action. Subclasses of UAPushAction should override this method to define custom behavior.
 *
 * @param arguments A UAPushActionArguments value representing the arguments passed to the action.
 * @param completionHandler A UAActionPushCompletionHandler that signals the completion of the action.
 * @return An instance of UAActionResult.
 */
- (void)performWithArguments:(UAPushActionArguments *)arguments withPushCompletionHandler:(UAActionPushCompletionHandler)completionHandler;

@end
