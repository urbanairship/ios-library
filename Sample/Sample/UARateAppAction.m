/* Copyright 2017 Urban Airship and Contributors */

#import "UARateAppAction.h"

@implementation UARateAppAction


- (BOOL)shouldDisplayRateDialog {

}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (arguments.situation == UASituationBackgroundPush) {
        return NO;
    }

    return (BOOL)([self parseURLFromValue:arguments.value] != nil);
}


@end
