/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UAWebViewDelegate.h"
#import "UAUser.h"
#import "UAWhitelist.h"
#import "UAInboxMessage.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UANativeBridge.h"
#import "UAirship+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebViewCallData.h"

@interface UAWebViewDelegate()
@property (nonatomic, strong) NSMapTable *injectedWebViews;
@end

@implementation UAWebViewDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        self.injectedWebViews = [NSMapTable weakToStrongObjectsMapTable];
    }

    return self;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

    // This will be nil if we are not loading a Rich Push message
    UAInboxMessage *message = [[UAInbox shared].messageList messageForBodyURL:request.URL];

    NSURL *url = [request URL];

    BOOL shouldLoad = YES;

    id strongDelegate = self.forwardDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        shouldLoad = [strongDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }

    // Always handle uairship urls
    // uairship://command/[<arguments>][?<dictionary>]
    if ([[url scheme] isEqualToString:@"uairship"] || [[url scheme] isEqualToString:@"ua"]) {
        if ([[UAirship shared].whitelist isWhitelisted:webView.request.mainDocumentURL]) {
            if ((navigationType == UIWebViewNavigationTypeLinkClicked) || (navigationType == UIWebViewNavigationTypeOther)) {
                UAWebViewCallData *data = [UAWebViewCallData callDataForURL:url webView:webView message:message];
                [self performJSDelegateWithData:data];
            }
        }

        shouldLoad = NO;
    }

    // Override any special link actions
    if (shouldLoad && navigationType == UIWebViewNavigationTypeLinkClicked) {
        shouldLoad = ![self handleLinkClick:url];
    }

    // Check if its a new page
    if (shouldLoad && [request.URL isEqual:[request mainDocumentURL]]) {
        [self.injectedWebViews setObject:@(NO) forKey:webView];
    }

    return shouldLoad;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    id strongDelegate = self.forwardDelegate;
    if ([strongDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [strongDelegate webViewDidFinishLoad:webView];
    }

    if (![[self.injectedWebViews objectForKey:webView] boolValue]) {
        [self.injectedWebViews setObject:@(YES) forKey:webView];

        UAWhitelist *whitelist = [UAirship shared].whitelist;
        NSURL *requestURL = webView.request.mainDocumentURL;
        if (![whitelist isWhitelisted:requestURL]) {
            UA_LINFO(@"URL %@ is not whitelisted, not populating JS interface", requestURL);
            return;
        }

        [self populateJavascriptEnvironment:webView];
    }
}

- (void)closeWebView:(UIWebView *)webView animated:(BOOL)animated {
    id strongContentWindow = self.richContentWindow;
    if ([strongContentWindow respondsToSelector:@selector(closeWebView:animated:)]) {
        [strongContentWindow closeWebView:webView animated:animated];
    } else if ([strongContentWindow respondsToSelector:@selector(closeWindow:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [strongContentWindow closeWindow:animated];
#pragma clang diagnostic pop
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    id strongDelegate = self.forwardDelegate;
    if ([strongDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [strongDelegate webViewDidStartLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    id strongDelegate = self.forwardDelegate;
    if ([strongDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [strongDelegate webView:webView didFailLoadWithError:error];
    }
}



- (void)populateJavascriptEnvironment:(UIWebView *)webView {
    // This will be nil if we are not loading a Rich Push message
    UAInboxMessage *message = [[UAInbox shared].messageList messageForBodyURL:webView.request.mainDocumentURL];

    /*
     * Define and initialize our one global
     */
    __block NSString *js = @"var UAirship = {};";

    void (^appendJavascriptProperty)(NSString *, NSString *, id) = ^(NSString *propertyName, NSString *methodName, id value){
        NSString *valueAsString;
        if (!value) {
            valueAsString = @"null";
        } else if ([value isKindOfClass:[NSString class]]) {
            valueAsString = [NSString stringWithFormat:@"\"%@\"", value];
        } else {
            valueAsString = [value stringValue];
        }

        js = [js stringByAppendingFormat:@"UAirship.%@ = %@;", propertyName, valueAsString];
        js = [js stringByAppendingFormat:@"UAirship.%@ = function() {return %@};", methodName, valueAsString];
    };

    /*
     * Set the device model.
     */
    appendJavascriptProperty(@"devicemodel", @"getDeviceModel", [UIDevice currentDevice].model);

    /*
     * Set the UA user ID.
     */
    appendJavascriptProperty(@"userID", @"getUserId", [UAUser defaultUser].username);

    /*
     * Set the current message ID.
     */
    appendJavascriptProperty(@"messageID", @"getMessageId", message.messageID);

    /*
     * Set the current message's title.
     */
    appendJavascriptProperty(@"messageTitle", @"getMessageTitle", message.title);

    /*
     * Set the current message's sent date
     */
    if (message.messageSent) {
        NSTimeInterval messageSentDateMS = [message.messageSent timeIntervalSince1970] * 1000;
        NSNumber *milliseconds = [NSNumber numberWithDouble:messageSentDateMS];
        appendJavascriptProperty(@"messageSentDateMS", @"getMessageSentDateMS", milliseconds);

        NSString *messageSentDate = [[UAUtils ISODateFormatterUTC] stringFromDate:message.messageSent];
        appendJavascriptProperty(@"messageSentDate", @"getMessageSentDate", messageSentDate);

    } else {
        appendJavascriptProperty(@"messageSentDateMS", @"getMessageSentDateMS", @(-1));
        appendJavascriptProperty(@"messageSentDate", @"getMessageSentDate", nil);
    }

    /*
     * Define action/native bridge functionality:
     *
     * UAirship.callbackURL,
     * UAirship.invoke,
     * UAirship.runAction,
     * UAirship.finishAction
     *
     * See Airship/Common/JS/UANativeBridge.js for human-readable source
     */

    NSData *data = [NSData dataWithBytes:(const char *)UANativeBridge_js length:UANativeBridge_js_len];
    NSString *bridge = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    js = [js stringByAppendingString:bridge];

    /*
     * Execute the JS we just constructed.
     */
    [webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)performJSDelegateWithData:(UAWebViewCallData *)data {
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

- (void)performAsyncJSCallWithDelegate:(id<UAJavaScriptDelegate>)delegate
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
- (void)performDeprecatedJSCallWithDelegate:(id<UAInboxJavaScriptDelegate>)delegate
                                       data:(UAWebViewCallData *)data {

    SEL selector = @selector(callbackArguments:withOptions:);
    if ([delegate respondsToSelector:selector]) {
        NSString *script = [delegate callbackArguments:data.arguments withOptions:data.options];
        if (script) {
            [data.webView stringByEvaluatingJavaScriptFromString:script];
        }
    }
}
#pragma clang diagnostic pop

- (NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url {

    NSString *decodedURLString = [url.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
    NSString *strippedNumber = [[decodedURLString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];

    NSString *scheme = [decodedURLString hasPrefix:@"sms"] ? @"sms:" : @"tel:";

    return [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
}


/**
 * Handles a link click.
 * 
 * @param url The link's URL.
 * @returns YES if the link was handled, otherwise NO.
 */
- (BOOL)handleLinkClick:(NSURL *)url {
    // Send iTunes/Phobos urls to AppStore.app
    if ([[url host] isEqualToString:@"phobos.apple.com"] || [[url host] isEqualToString:@"itunes.apple.com"]) {
        // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
        NSString *stringURL = [NSString stringWithFormat:@"http://%@%@", url.host, url.path];
        return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:stringURL]];
    }

    // Send maps.google.com url or maps: to GoogleMaps.app
    if ([[url host] isEqualToString:@"maps.google.com"] || [[url scheme] isEqualToString:@"maps"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send www.youtube.com url to YouTube.app
    if ([[url host] isEqualToString:@"www.youtube.com"]) {
         return [[UIApplication sharedApplication] openURL:url];
    }

    // Send mailto: to Mail.app
    if ([[url scheme] isEqualToString:@"mailto"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send tel: to Phone.app
    if ([[url scheme] isEqualToString:@"tel"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    // Send sms: to Messages.app
    if ([[url scheme] isEqualToString:@"sms"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    return NO;
}


@end
