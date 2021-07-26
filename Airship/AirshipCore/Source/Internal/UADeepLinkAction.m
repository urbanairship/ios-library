/* Copyright Airship and Contributors */

#import "UADeepLinkAction.h"
#import "UAirship.h"
#import "UAActionArguments.h"
#import "UAActionResult.h"

@implementation UADeepLinkAction

NSString * const UADeepLinkActionDefaultRegistryName = @"deep_link_action";
NSString * const UADeepLinkActionDefaultRegistryAlias = @"^d";

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
        if (![[UAirship shared].URLAllowList isAllowed:url scope:UAURLAllowListScopeOpenURL]) {
            UA_LERR(@"URL %@ not allowed. Unable to open url.", url);
            NSError *error =  [NSError errorWithDomain:UAOpenExternalURLActionErrorDomain
                                                  code:UAOpenExternalURLActionErrorCodeURLFailedToOpen
                                              userInfo:@{NSLocalizedDescriptionKey : @"URL not allowed."}];
            completionHandler([UAActionResult resultWithError:error]);
        } else {
            [super performWithArguments:arguments completionHandler:completionHandler];
        }
    }
}

@end
