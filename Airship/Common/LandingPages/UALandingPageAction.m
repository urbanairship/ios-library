/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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
#import "UAHTTPConnection.h"
#import "UALandingPageOverlayController.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "NSString+UAURLEncoding.h"
#import "UAUtils.h"

@interface UALandingPageAction()
@property (nonatomic, strong) UAHTTPConnection *connection;
@end


@implementation UALandingPageAction

- (NSURL *)parseShortURL:(NSString *)urlString {
    if ([urlString length] <= 2) {
        return nil;
    }

    NSString *contentId = [urlString substringFromIndex:2];
    return [NSURL URLWithString:[UAirship.shared.config.landingPageContentURL stringByAppendingFormat:@"/%@/%@",
                                 UAirship.shared.config.appKey,
                                 [contentId urlEncodedStringWithEncoding:NSUTF8StringEncoding]]];
}

- (NSURL *)parseURLFromValue:(id)value {

    NSURL *url;

    if ([value isKindOfClass:[NSURL class]]) {
        url = value;
    } else if ([value isKindOfClass:[NSString class]]) {
        if ([value hasPrefix:@"u:"]) {
            url = [self parseShortURL:value];
        } else {
            url = [NSURL URLWithString:value];
        }
    }

    if  (url && !url.scheme.length) {
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:[url absoluteString]]];
    }

    return url;
}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)actionName
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSURL *landingPageURL = [self parseURLFromValue:arguments.value];

    // Include app auth for any content id requests
    BOOL isContentUrl = [landingPageURL.absoluteString hasPrefix:UAirship.shared.config.landingPageContentURL];

    // set cachable url
    [UAURLProtocol addCachableURL:landingPageURL];

    if (arguments.situation == UASituationBackgroundPush) {
        // pre-fetch url so that it can be accessed later from the cache
        if (isContentUrl) {
            [self prefetchURL:landingPageURL
                 withUsername:UAirship.shared.config.appKey
                 withPassword:UAirship.shared.config.appSecret
        withCompletionHandler:completionHandler];
        } else {
            [self prefetchURL:landingPageURL withUsername:nil
                 withPassword:nil withCompletionHandler:completionHandler];
        }
    } else {
        //close any existing windows
        [UALandingPageOverlayController closeAll:NO];

        NSMutableDictionary *headers = [NSMutableDictionary dictionary];

        if (isContentUrl) {
            [headers setValue:[UAUtils appAuthHeaderString] forKey:@"Authorization"];
        }

        //load the landing page
        [UALandingPageOverlayController showURL:landingPageURL withHeaders:headers];
        completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
    }
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (arguments.situation == UASituationBackgroundPush && UAirship.shared.config.cacheDiskSizeInMB == 0) {
        return NO;
    }

    return (BOOL)([self parseURLFromValue:arguments.value] != nil);
}

- (void)prefetchURL:(NSURL *)landingPageURL withUsername:(NSString *)username
       withPassword:(NSString *)password withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    if (self.connection) {
        [self.connection cancel];
    }

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request) {
        UA_LTRACE(@"Retrieved landing page with status code %ld at url: %@.",
                  (long)[request.response statusCode], request.url);

        if ([request.response statusCode] == 200) {
            UA_LTRACE(@"Cached landing page.");
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
        } else {
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultFailed]);
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request) {
        UA_LTRACE(@"Error %@ for landing page pre-fetch request at url: %@", request.error, request.url);
        completionHandler([UAActionResult resultWithError:request.error withFetchResult:UAActionFetchResultFailed]);
    };

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:landingPageURL];
    request.username = username;
    request.password = password;

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];

    [self.connection start];
}

@end
