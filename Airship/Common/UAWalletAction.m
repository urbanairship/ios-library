//
//  UAWalletAction.m
//  Goat
//
//  Created by Jeff Towle on 10/21/13.
//
//

#import "UAWalletAction.h"

#import "UAGlobal.h"
#import "UAInboxUI.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"
#import "UAHTTPRequest.h"

#import "UAPushActionArguments.h"
#import "UAActionRegistrar.h"

#import <PassKit/PassKit.h>

@interface UAWalletAction ()

@property(nonatomic, strong) UAHTTPConnection *connection;

+ (UIViewController *)topController;

- (void)fetchPassWithURL:(NSURL *)passURL
              forDisplay:(BOOL)display
   withCompletionHandler:(UAActionCompletionHandler)completionHandler;
@end

@implementation UAWalletAction

// a utility method that grabs the top-most view controller
+ (UIViewController *)topController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSString *situation = arguments.situation;
    NSURL *passURL = [NSURL URLWithString:arguments.value];

    //UIViewController *topController = [UAWalletAction topController];

    NSArray *displaySituations = @[UASituationForegroundPush,
                                   UASituationLaunchedFromPush,
                                   UASituationManualInvocation];
    if ([displaySituations containsObject:situation]) {
        [self fetchPassWithURL:passURL forDisplay:YES withCompletionHandler:completionHandler];
    } else if ([situation isEqualToString:UASituationBackgroundPush]) {
        // pre-cache. set pending-kablam flag

        // set cachable url
        [UAURLProtocol addCachableURL:passURL];

        // fetch url, then set flag in completion block
        [self fetchPassWithURL:passURL forDisplay:NO withCompletionHandler:completionHandler];

    } else {
        completionHandler([UAActionResult none]);
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    NSArray *validSituations = @[UASituationForegroundPush,
                                 UASituationLaunchedFromPush,
                                 UASituationBackgroundPush,
                                 UASituationManualInvocation];

    if (!arguments.situation || ![validSituations containsObject:arguments.situation]) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [super acceptsArguments:arguments];
}

- (void)fetchPassWithURL:(NSURL *)passURL forDisplay:(BOOL)display withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Received PASS DL SUCCESS %ld for request %@.", (long)[request.response statusCode], request.url);

        // 200, cache response
        if ([request.response statusCode] == 200) {
            UA_LTRACE(@"Fetched Pass!");

            NSError *error = nil;
            PKPass *pass = [[PKPass alloc] initWithData:request.responseData error:&error];
            if (error) {
                UALOG(@"Failed to download a pass %@", [error description]);
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
            } else {
                if (pass && display) {
                    PKPassLibrary *library = [[PKPassLibrary alloc] init];
                    [library addPasses:@[pass] withCompletionHandler:^ (PKPassLibraryAddPassesStatus status) {
                        if (status == PKPassLibraryShouldReviewPasses) {
                            PKAddPassesViewController *passController = [[PKAddPassesViewController alloc] initWithPass:pass];
                            UIViewController *topController = [UAWalletAction topController];
                            //present on the top view controller
                            [topController presentViewController:passController animated:YES completion:nil];
                        }
                    }];
                }
                // maybe this should go in the presentViewController completion in that case??????
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
            }

        } else {
            UALOG(@"Failed to download a pass %ld", (long)request.response.statusCode);
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Error %@ for PASS request %@.", request.error, request.url);
        completionHandler([UAActionResult none]);//TODO: error, no data
    };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:passURL];

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];
    
    [self.connection start];
}

@end
