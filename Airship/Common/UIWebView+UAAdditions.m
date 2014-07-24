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

#import "UIWebView+UAAdditions.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "UANativeBridge.h"

@implementation UIWebView (UAAdditions)

- (void)populateJavascriptEnvironment:(UAInboxMessage *)message {

    // This will inject the current device orientation
    // Note that face up and face down orientations will be ignored as this
    // casts a device orientation to an interface orientation
    [self injectInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];

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
    [self stringByEvaluatingJavaScriptFromString:js];
}


- (void)populateJavascriptEnvironment {
    [self populateJavascriptEnvironment:nil];
}

- (void)fireUALibraryReadyEvent {
    NSString *js = @"var uaLibraryReadyEvent = document.createEvent('Event');\
    uaLibraryReadyEvent.initEvent('ualibraryready', true, true); \
    document.dispatchEvent(uaLibraryReadyEvent);";

    [self stringByEvaluatingJavaScriptFromString:js];
}

- (void)injectInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {

    switch (toInterfaceOrientation) {
        case UIDeviceOrientationPortrait:
            [self stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 0;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationLandscapeLeft:
            [self stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 90;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationLandscapeRight:
            [self stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return -90;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            [self stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 180;});window.onorientationchange();"];
            break;
        default:
            break;
    }
}

@end
