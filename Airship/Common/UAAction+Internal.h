

#import "UAAction.h"

@interface UAAction ()

@property(nonatomic, copy) UAActionBlock actionBlock;
@property(nonatomic, copy) UAActionPredicate acceptsArgumentsBlock;
@property(nonatomic, copy) UAActionVoidBlock onRunBlock;

- (void)runWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;
@end
