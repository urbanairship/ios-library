
#import "UACloseWindowAction.h"
#import "UALandingPageViewController.h"

@implementation UACloseWindowAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    BOOL acceptsValue = [arguments.value isKindOfClass:[NSNumber class]] ||
        !arguments.value;

    return acceptsValue;
}

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    BOOL animated = NO;
    if (arguments.value) {
        animated = [((NSNumber *)arguments.value) boolValue];
    }

    [UALandingPageViewController closeWindow:animated];
}

@end
