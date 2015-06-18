/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ''AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <PassKit/PassKit.h>

#import "UAWalletAction.h"
#import "UAGlobal.h"
#import "UAURLProtocol.h"
#import "UAHTTPRequest.h"
#import "UAActionRegistry.h"
#import "UAUtils.h"
#import "UAWalletAction+Internal.h"

@implementation UAWalletAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    // if pass library isn't available reject all arguments
    if (![PKPassLibrary isPassLibraryAvailable]) {
        UA_LDEBUG(@"Unable to perform wallet action on this device - pass library unavailable.");
        return NO;
    }

    switch (arguments.situation) {
        case UASituationForegroundPush:
        case UASituationLaunchedFromPush:
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationForegroundInteractiveButton:
        case UASituationBackgroundPush:
            return [arguments.value isKindOfClass:[NSString class]];
        case UASituationBackgroundInteractiveButton:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSURL *passURL = [NSURL URLWithString:arguments.value];

    switch (arguments.situation) {

            // Foreground situations
        case UASituationForegroundPush:
        case UASituationLaunchedFromPush:
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationForegroundInteractiveButton:
            [self fetchPassWithURL:passURL display:YES completionHandler:completionHandler];
            break;

            // Background situations
        case UASituationBackgroundPush:
            // Pre-cache in the background
            // Set cachable url
            [UAURLProtocol addCachableURL:passURL];

            // Fetch url, then set flag in completion block
            [self fetchPassWithURL:passURL display:NO completionHandler:completionHandler];
            break;

            // Unhandled situations
        case UASituationBackgroundInteractiveButton:
            // Should reject
            completionHandler([UAActionResult emptyResult]);
            break;
    }

}

/**
 * Retrieve a Passbook Pass and either cache or display it in the standard 'Add Pass' view controller.
 *
 * @param passURL The PKPass file URL
 * @param display Optionally display the add pass dialog if `YES`, otherwise simply precache the pass
 * @param completionHandler The standard action completion handler. This must be called or scheduled
 *                          asynchronously from this method.
 *
 */
- (void)fetchPassWithURL:(NSURL *)passURL display:(BOOL)display completionHandler:(UAActionCompletionHandler)completionHandler {
    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){

        // If response is not OK, return early
        if ([request.response statusCode] != 200) {
            UA_LDEBUG(@"Failed to download a pass %ld", (long)request.response.statusCode);
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
            return;
        }

        UA_LTRACE(@"Pass downloaded successfully with HTTP response %ld for request %@.", (long)[request.response statusCode], request.url);
        NSError *error = nil;
        PKPass *pass = [[PKPass alloc] initWithData:request.responseData error:&error];

        if (error) {
            UA_LDEBUG(@"Failed to initialize a pass %@", [error description]);
            completionHandler([UAActionResult resultWithError:error withFetchResult:UAActionFetchResultNewData]);
            return;
        }

        if (pass && display) {
            if ([self.passLibrary containsPass:pass]) {
                UA_LDEBUG(@"Passbook library already contains the pass %@, skipping add", pass.localizedName);
                completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
                return;
            }

            [self.passLibrary addPasses:@[pass] withCompletionHandler:^ (PKPassLibraryAddPassesStatus status) {
                if (status == PKPassLibraryShouldReviewPasses) {
                    PKAddPassesViewController *passController = [[PKAddPassesViewController alloc] initWithPass:pass];
                    UIViewController *topController = [UAUtils topController];

                    // Present on the top view controller
                    [topController presentViewController:passController animated:YES completion:nil];
                }
            }];
        }

        // Success - report that we have new data
        completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);

    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Error %@ for pass request %@.", request.error, request.url);
        completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
    };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:passURL];

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];

    [self.connection start];
}

- (PKPassLibrary *)passLibrary {
    if (!_passLibrary && [PKPassLibrary isPassLibraryAvailable]) {
        _passLibrary = [[PKPassLibrary alloc] init];
    }
    return _passLibrary;
}

@end
