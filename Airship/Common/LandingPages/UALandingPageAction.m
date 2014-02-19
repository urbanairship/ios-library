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
#import "UAInboxUI.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"
#import "UALandingPageViewController.h"
#import "UAPushActionArguments.h"
#import "UAActionRegistrar.h"

@interface UALandingPageAction()

@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UALandingPageAction

// A URL: https://sbux-dl-staging.urbanairship.com/binary/public/kwG7rEc3Tz6542jxYJ4eWA/da67242f-a22c-440c-a270-1a78e0917334

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UASituation situation = arguments.situation;
    NSURL *landingPageURL = [NSURL URLWithString:arguments.value];

    NSArray *displaySituations = @[[NSNumber numberWithInteger:UASituationForegroundPush],
                                    [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                    [NSNumber numberWithInteger:UASituationLaunchedFromSpringBoard],
                                    [NSNumber numberWithInteger:UASituationManualInvocation]];

    // set cachable url
    [UAURLProtocol addCachableURL:landingPageURL];

    //close any existing windows
    [UALandingPageViewController closeWindow:NO];

    if ([displaySituations containsObject:[NSNumber numberWithInteger:situation]]) {
        //load the landing page
        [UALandingPageViewController showURL:landingPageURL];
        completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
    } else if (situation == UASituationBackgroundPush) {
        // pre-cache. set pending-landing-page flag

        //TODO: plan for this... we may want to schedule for springboard, but cancel it if the displayable view
        //is launched
        //[UAPushActionArguments addPendingSpringBoardAction:@"landing_page_action" value:arguments.value];


        // fetch url, then set flag in completion block
        [self prefetchURL:landingPageURL withCompletionHandler:completionHandler];

    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    NSArray *validSituations = @[[NSNumber numberWithInteger:UASituationForegroundPush],
                                 [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                 [NSNumber numberWithInteger:UASituationBackgroundPush],
                                 [NSNumber numberWithInteger:UASituationForegroundPush],
                                 [NSNumber numberWithInteger:UASituationLaunchedFromSpringBoard],
                                 [NSNumber numberWithInteger:UASituationManualInvocation]];

    if (!arguments.situation || ![validSituations containsObject:[NSNumber numberWithInteger:arguments.situation]]) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [super acceptsArguments:arguments];
}

- (void)prefetchURL:(NSURL *)landingPageURL withCompletionHandler:(UAActionCompletionHandler)completionHandler {

     UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
         UA_LTRACE(@"Received landing page success %ld for request %@.", (long)[request.response statusCode], request.url);

         // 200, cache response
         if ([request.response statusCode] == 200) {
             UA_LTRACE(@"Precached landing page.");
             completionHandler([UAActionResult emptyResult]);//TODO: it actually has data!
         } else {
             completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);//TODO: it actually has data!
         }
     };

     UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
         UA_LTRACE(@"Error %@ for langing page request %@, attempting to fall back to cache.", request.error, request.url);
         completionHandler([UAActionResult emptyResult]);//TODO: error, no data
     };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:landingPageURL];

     self.connection = [UAHTTPConnection connectionWithRequest:request
                                                  successBlock:successBlock
                                                  failureBlock:failureBlock];
     
     [self.connection start];
}

@end
