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

#import "UAKablamAction.h"


#import "UAGlobal.h"
#import "UAInboxUI.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"
#import "UAKablamOverlayController.h"
#import "UAKablamViewController.h"
#import "UAPushActionArguments.h"
#import "UAActionRegistrar.h"

@interface UAKablamAction()

@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UAKablamAction

// A URL: https://sbux-dl-staging.urbanairship.com/binary/public/kwG7rEc3Tz6542jxYJ4eWA/da67242f-a22c-440c-a270-1a78e0917334

+ (UIViewController *)topController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (void)performWithArguments:(UAPushActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSString *situation = arguments.situation;
    NSURL *kablamURL = [NSURL URLWithString:arguments.value];

    UIViewController *topController = [UAKablamAction topController];

    if ([situation isEqualToString:UASituationForegroundPush]) {

        // show the widget, then load
        //[UAKablamOverlayController showWindowInsideViewController:topController withURL:kablamURL];
        [UAKablamViewController showInsideViewController:topController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationLaunchedFromPush]) {
        // show the widget, then load (if not already)
        //[UAKablamOverlayController showWindowInsideViewController:topController withURL:kablamURL];
        [UAKablamViewController showInsideViewController:topController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationLaunchedFromSpringBoard]) {

        // show the widget, then load (if not already)
        //[UAKablamOverlayController showWindowInsideViewController:topController withURL:kablamURL];
        [UAKablamViewController showInsideViewController:topController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationBackgroundPush]) {
        // pre-cache. set pending-kablam flag

        [UAPushActionArguments addPendingSpringBoardAction:@"kablam" value:arguments.value];

        // set cachable url
        [UAURLProtocol addCachableURL:kablamURL];

        // fetch url, then set flag in completion block
        [self prefetchURL:kablamURL withCompletionHandler:completionHandler];

    } else {
        completionHandler([UAActionResult none]);
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    NSArray *validSituations = @[UASituationForegroundPush,
                                 UASituationLaunchedFromPush,
                                 UASituationBackgroundPush,
                                 UASituationForegroundPush,
                                 UASituationLaunchedFromSpringBoard];

    if (!arguments.situation || ![validSituations containsObject:arguments.situation]) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [super acceptsArguments:arguments];
}

- (void)prefetchURL:(NSURL *)kablamURL withCompletionHandler:(UAActionCompletionHandler)completionHandler {

     UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
         UA_LTRACE(@"Received KABLAM SUCCESS %ld for request %@.", (long)[request.response statusCode], request.url);

         // 200, cache response
         if ([request.response statusCode] == 200) {
             UA_LTRACE(@"Precached KABLAM.");
             completionHandler([UAActionResult none]);//TODO: it actually has data!
         }
     };

     UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
         UA_LTRACE(@"Error %@ for KABLAM request %@, attempting to fall back to cache.", request.error, request.url);
         completionHandler([UAActionResult none]);//TODO: error, no data
     };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:kablamURL];

     self.connection = [UAHTTPConnection connectionWithRequest:request
                                                  successBlock:successBlock
                                                  failureBlock:failureBlock];
     
     [self.connection start];
}

@end
