/* Copyright 2017 Urban Airship and Contributors */

#import "UADeepLinkAction.h"
#import "UAirship.h"

@implementation UADeepLinkAction

- (void)performWithArguments:(UAActionArguments *)arguments completionHandler:(UAActionCompletionHandler)completionHandler{
    id strongDelegate = [UAirship shared].deepLinkDelegate;
    if ([strongDelegate respondsToSelector:@selector(receivedDeepLink:completionHandler:)]) {
        NSURL *url = [arguments.value isKindOfClass:[NSURL class]] ? arguments.value : [NSURL URLWithString:arguments.value];
        [strongDelegate receivedDeepLink:url completionHandler:^{
            completionHandler([UAActionResult resultWithValue:url.absoluteString]);
        }];
    } else{
        [super performWithArguments:arguments completionHandler:completionHandler];
    }
}

@end
