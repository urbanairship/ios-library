
#import "UAPushAction.h"

@interface UAPushAction()
@property (nonatomic, copy) UAPushActionBlock actionBlock;
@end

@implementation UAPushAction

- (instancetype)initWithBlock:(UAPushActionBlock)actionBlock {
    self = [super init];
    if (self) {
        self.actionBlock = actionBlock;
    }

    return self;
}

+ (instancetype)pushActionWithBlock:(UAPushActionBlock)actionBlock {
    return [[UAPushAction alloc] initWithBlock:actionBlock];
}

- (void)performWithArguments:(id)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    [self performWithArguments:arguments withPushCompletionHandler:^(UAActionResult *result){
        completionHandler(result);
    }];
}

- (void)performWithArguments:(UAActionArguments *)arguments withPushCompletionHandler:(UAActionPushCompletionHandler)completionHandler {
    if (self.actionBlock) {
        self.actionBlock(arguments, completionHandler);
    }
}

@end
