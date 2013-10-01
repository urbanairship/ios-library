
#import "UAAction.h"

@interface UAAction ()

- (void)runWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@property(nonatomic, copy) UAActionBlock actionBlock;
@property(nonatomic, copy) UAActionPredicate predicateBlock;

@end
