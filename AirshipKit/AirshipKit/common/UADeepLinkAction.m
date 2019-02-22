/* Copyright Urban Airship and Contributors */

#import "UADeepLinkAction.h"
#import "UAirship.h"

@implementation UADeepLinkAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    NSURL *url = [UAOpenExternalURLAction parseURLFromArguments:arguments];
    if (!url) {
        return NO;
    }

    return YES;
}

- (void)performWithArguments:(UAActionArguments *)arguments completionHandler:(UAActionCompletionHandler)completionHandler{
    NSURL *url = [UAOpenExternalURLAction parseURLFromArguments:arguments];

    id strongDelegate = [UAirship shared].deepLinkDelegate;
    if ([strongDelegate respondsToSelector:@selector(receivedDeepLink:completionHandler:)]) {
        [strongDelegate receivedDeepLink:url completionHandler:^{
            completionHandler([UAActionResult resultWithValue:url.absoluteString]);
        }];
    } else{
        if (![[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeOpenURL]) {
            UA_LERR(@"URL %@ not whitelisted. Unable to open url.", url);
            NSError *error =  [NSError errorWithDomain:UAOpenExternalURLActionErrorDomain
                                                  code:UAOpenExternalURLActionErrorCodeURLFailedToOpen
                                              userInfo:@{NSLocalizedDescriptionKey : @"URL not whitelisted."}];
            completionHandler([UAActionResult resultWithError:error]);
        } else {
            [super performWithArguments:arguments completionHandler:completionHandler];
        }
    }
}

@end
