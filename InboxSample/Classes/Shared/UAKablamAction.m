//
//  UAKablamAction.m
//  AirshipLib
//
//  Created by Jeff Towle on 9/26/13.
//
//

#import "UAKablamAction.h"


#import "UAGlobal.h"
#import "UAInboxUI.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"
#import "UAKablamOverlayController.h"
#import "UAPushActionArguments.h"

@interface UAKablamAction()

@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UAKablamAction

// A URL: https://sbux-dl-staging.urbanairship.com/binary/public/kwG7rEc3Tz6542jxYJ4eWA/da67242f-a22c-440c-a270-1a78e0917334


- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSString *situation = arguments.situation;
    NSURL *kablamURL = [NSURL URLWithString:arguments.value];

    if ([situation isEqualToString:UASituationForegroundPush]) {
        // show the widget, then load
        [UAKablamOverlayController showWindowInsideViewController:[UAInboxUI shared].inboxParentController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationLaunchedFromPush]) {
        // show the widget, then load (if not already)
        [UAKablamOverlayController showWindowInsideViewController:[UAInboxUI shared].inboxParentController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationLaunchedFromSpringBoard]) {

        // show the widget, then load (if not already)
        [UAKablamOverlayController showWindowInsideViewController:[UAInboxUI shared].inboxParentController withURL:kablamURL];
        completionHandler([UAActionResult none]);

    } else if ([situation isEqualToString:UASituationBackgroundPush]) {
        // pre-cache. set pending-kablam flag
        //TODO:
        [UAPushActionArguments deferToSpringBoardLaunch:(UAPushActionArguments *)arguments];

        // set cachable url
        [UAURLProtocol addCachableURL:kablamURL];

        // fetch url, then set flag in completion block
        [self prefetchURL:kablamURL withCompletionHandler:completionHandler];

    } else {
        completionHandler([UAActionResult none]);
    }
}

- (BOOL)canPerformWithArguments:(UAActionArguments *)arguments {

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

    return [super canPerformWithArguments:arguments];
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

- (void)kablamNextStartWithURL:(NSURL *)kablamURL {

}

- (void)kablamIfNecessary {
    // on start, kablam
}

- (void)removeKablam {
    // cancel the kablam
}

@end
