/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "UALandingPageAction.h"

#import "UAGlobal.h"
#import "UAURLProtocol.h"
#import "UALandingPageViewController.h"
#import "UAHTTPConnection.h"

@interface UALandingPageAction()
@property(nonatomic, strong) UAHTTPConnection *connection;
@end

@implementation UALandingPageAction

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSURL *landingPageURL;
    if ([arguments.value isKindOfClass:[NSURL class]]) {
        landingPageURL = arguments.value;
    } else {
        landingPageURL = [NSURL URLWithString:arguments.value];
    }

    // set cachable url
    [UAURLProtocol addCachableURL:landingPageURL];

    if (arguments.situation == UASituationBackgroundPush ) {
        // pre-fetch url so that it can be accessed later from the cache
        [self prefetchURL:landingPageURL withCompletionHandler:completionHandler];
    } else {
        //close any existing windows
        [UALandingPageViewController closeWindow:NO];

        //load the landing page
        [UALandingPageViewController showURL:landingPageURL];
        completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (![arguments.value isKindOfClass:[NSString class]] &&
        ![arguments.value isKindOfClass:[NSURL class]]) {
        return NO;
    }

    return YES;
}

- (void)prefetchURL:(NSURL *)landingPageURL withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    if (self.connection) {
        [self.connection cancel];
    }

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Retrieved landing page with status code %ld at url: %@.",
                  (long)[request.response statusCode], request.url);

        if ([request.response statusCode] == 200) {
            UA_LTRACE(@"Cached landing page.");
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
        } else {
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Error %@ for landing page pre-fetch request at url: %@", request.error, request.url);
        completionHandler([UAActionResult resultWithError:request.error withFetchResult:UAActionFetchResultFailed]);
    };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:landingPageURL];

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];

    [self.connection start];
}

@end
