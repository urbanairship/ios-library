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

#import "UAWebViewTools.h"

#import "UAirship+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebViewCallData.h"

@implementation UAWebViewTools


+ (NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url {

    NSString *decodedUrlString = [url.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
    NSString *strippedNumber = [[decodedUrlString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];

    NSString *scheme = [decodedUrlString hasPrefix:@"sms"] ? @"sms:" : @"tel:";

    return [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
}

+ (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return [UAWebViewTools webView:wv shouldStartLoadWithRequest:request navigationType:navigationType message:nil];
  }

+ (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType message:(UAInboxMessage *)message {
    NSURL *url = [request URL];

    /*
     uairship://command/[<arguments>][?<dictionary>]
     */

    if ([[url scheme] isEqualToString:@"uairship"] || [[url scheme] isEqualToString:@"ua"]) {
        if ((navigationType == UIWebViewNavigationTypeLinkClicked) || (navigationType == UIWebViewNavigationTypeOther)) {
            UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url webView:wv message:message];
            [self performJSDelegateWithData:data];
            return NO;
        }
    }

    // send iTunes/Phobos urls to AppStore.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             (([[url host] isEqualToString:@"phobos.apple.com"]) ||
              ([[url host] isEqualToString:@"itunes.apple.com"]))) {

                 // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
                 NSString *stringURL = [NSString stringWithFormat:@"http://%@%@", url.host, url.path];
                 return ![[UIApplication sharedApplication] openURL:[NSURL URLWithString:stringURL]];
             }

    // send maps.google.com url or maps: to GoogleMaps.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             (([[url host] isEqualToString:@"maps.google.com"]) ||
              ([[url scheme] isEqualToString:@"maps"]))) {

                 /* Do any special formatting here, for example:

                  NSString *title = @"title";
                  float latitude = 35.4634;
                  float longitude = 9.43425;
                  int zoom = 13;
                  NSString *stringURL = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%@@%1.6f,%1.6f&z=%d", title, latitude, longitude, zoom];

                  */

                 return ![[UIApplication sharedApplication] openURL:url];
             }

    // send www.youtube.com url to YouTube.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             ([[url host] isEqualToString:@"www.youtube.com"])) {
        return ![[UIApplication sharedApplication] openURL:url];
    }

    // send mailto: to Mail.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"mailto"])) {

        /* Do any special formatting here if you like, for example:

         NSString *subject = @"Message subject";
         NSString *body = @"Message body";
         NSString *address = @"address@domain.com";
         NSString *cc = @"address@domain.com";
         NSString *path = [NSString stringWithFormat:@"mailto:%@?cc=%@&subject=%@&body=%@", address, cc, subject, body];
         NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

         For complex body text you may want to use CFURLCreateStringByAddingPercentEscapes.

         */

        return ![[UIApplication sharedApplication] openURL:url];
    }

    // send tel: to Phone.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"tel"])) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return ![[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    // send sms: to Messages.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"sms"])) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return ![[UIApplication sharedApplication] openURL:validPhoneUrl];
    }
    
    // load local file and http/https webpages in webview
    return YES;
}

+ (void)performJSDelegateWithData:(UAWebViewCallData *)data {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    id<UAInboxJavaScriptDelegate> inboxJSDelegate = [UAInbox shared].jsDelegate;
#pragma clang diagnostic pop
    id <UAJavaScriptDelegate> actionJSDelegate = [UAirship shared].actionJSDelegate;
    id <UAJavaScriptDelegate> userJSDDelegate = [UAirship shared].jsDelegate;

    BOOL isUsingNewScheme = [data.url.scheme isEqualToString:@"uairship"];
    BOOL isUsingDeprecatedScheme = [data.url.scheme isEqualToString:@"ua"];

    if (isUsingNewScheme) {
        if ([data.name isEqualToString:@"run-actions"] ||
            [data.name isEqualToString:@"run-basic-actions"] ||
            [data.name isEqualToString:@"run-action-cb"]) {

            [self performAsyncJSCallWithDelegate:actionJSDelegate data:data];

        } else {
            [self performAsyncJSCallWithDelegate:userJSDDelegate data:data];
        }
    } else if (isUsingDeprecatedScheme) {
        //deprecated inbox JS delegate, if applicable
        [self performDeprecatedJSCallWithDelegate:inboxJSDelegate
                                         data:data];
    }
}

+ (void)performAsyncJSCallWithDelegate:(id<UAJavaScriptDelegate>)delegate
                                  data:(UAWebViewCallData *)data {

    SEL selector = @selector(callWithData:withCompletionHandler:);
    if ([delegate respondsToSelector:selector]) {
        __weak UIWebView *weakWebView = data.webView;
        [delegate callWithData:data withCompletionHandler:^(NSString *script){
            [weakWebView stringByEvaluatingJavaScriptFromString:script];
        }];
    }
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (void)performDeprecatedJSCallWithDelegate:(id<UAInboxJavaScriptDelegate>)delegate
                                       data:(UAWebViewCallData *)data {
    //SEL selector = NSSelectorFromString(@"callbackArguments:withOptions:");
    SEL selector = @selector(callbackArguments:withOptions:);
    if ([delegate respondsToSelector:selector]) {
        NSString *script = nil;
        script = [delegate callbackArguments:data.arguments withOptions:data.options];
        if (script) {
            [data.webView stringByEvaluatingJavaScriptFromString:script];
        }
    }
}
#pragma clang diagnostic pop

@end
