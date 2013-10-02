
#import "UAAction.h"

@interface UAAction ()

@property(nonatomic, copy) UAActionBlock actionBlock;
@property(nonatomic, copy) UAActionPredicate acceptsArgumentsBlock;
@property(nonatomic, copy) UAActionExtraBlock onRunBlock;
- (void)runWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;
@end
