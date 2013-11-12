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

#import "UIWebView+UAAdditions.h"
#import "UAUser.h"
#import "UAUtils.h"

@implementation UIWebView (UAAdditions)

- (void)populateJavascriptEnvironment:(UAInboxMessage *)message {

    // This will inject the current device orientation
    // Note that face up and face down orientations will be ignored as this
    // casts a device orientation to an interface orientation
    [self willRotateToInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];

    /*
     * Define and initialize our one global
     */
    NSString *js = @"var UAirship = {};";

    /*
     * Set the device model.
     */
    NSString *model = [UIDevice currentDevice].model;
    js = [js stringByAppendingFormat:@"UAirship.devicemodel=\"%@\";", model];

    /*
     * Set the UA user ID.
     */
    NSString *userID = [UAUser defaultUser].username;
    js = [js stringByAppendingFormat:@"UAirship.userID=\"%@\";", userID];

    /*
     * Set the current message ID.
     */
    NSString *messageID = message.messageID;
    js = [js stringByAppendingFormat:@"UAirship.messageID=\"%@\";", messageID];

    /*
     * Set the current message's sent date (GMT).
     */
    NSDate *date = message.messageSent;
    NSString *messageSentDate = [[UAUtils ISODateFormatterUTC] stringFromDate:date];
    js = [js stringByAppendingFormat:@"UAirship.messageSentDate=\"%@\";", messageSentDate];

    /*
     * Set the current message's sent date (unix epoch time in milliseconds).
     */
    NSString *messageSentDateMS = [NSString stringWithFormat:@"%.0f", [date timeIntervalSince1970] * 1000];
    js =[js stringByAppendingFormat:@"UAirship.messageSentDateMS=%@;", messageSentDateMS];

    /*
     * Set the current message's title.
     */
    NSString *messageTitle = message.title;
    js = [js stringByAppendingFormat:@"UAirship.messageTitle=\"%@\";", messageTitle];

    /*
     * Define action/native bridge functionality:
     *
     * UAirship.callbackURL,
     * UAirship.invoke,
     * UAirship.runAction,
     * UAirship.finishAction
     *
     * See Airship/Common/UANativeBridge.js for uniminified, unescaped source
     */
    NSString *bridge = @"var id=0;UAirship.callbackURL=function(){var e=arguments;var t=[];var n=null;for(var r=0;r<e.length;r++){var i=e[r];if(i==undefined||i==null){i=\"\"}if(typeof i==\"object\"){n=i}else{t.push(encodeURIComponent(i))}}var s=\"ua://callbackArguments:withOptions:/\"+t.join(\"/\");if(n!=null){var o=[];for(var u in n){if(typeof u!=\"string\"){continue}o.push(encodeURIComponent(u)+\"=\"+encodeURIComponent(n[u]))}if(o.length>0){s+=\"?\"+o.join(\"&\")}}return s};UAirship.invoke=function(e){var t=document.createElement(\"iframe\");t.style.display=\"none\";t.src=e;document.body.appendChild(t);t.parentNode.removeChild(t)};UAirship.runAction=function(e,t,n){function o(e,t){delete window[i];try{n(e,JSON.parse(t))}catch(e){}}var r={};id++;var i=\"ua-cb-\"+id;r[e]=JSON.stringify(t);var s=UAirship.callbackURL(\"run-action\",i,r);window[i]=o;UAirship.invoke(s)};UAirship.finishAction=function(e,t,n){if(n in window){var r=window[n];r(e,t)}}";

    js = [js stringByAppendingString:bridge];

    /*
     * Execute the JS we just constructed.
     */
    [self stringByEvaluatingJavaScriptFromString:js];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {

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

- (void)injectViewportFix {
    NSString *js = @"var metaTag = document.createElement('meta');"
    "metaTag.name = 'viewport';"
    "metaTag.content = 'width=device-width; initial-scale=1.0; maximum-scale=1.0;';"
    "document.getElementsByTagName('head')[0].appendChild(metaTag);";

    [self stringByEvaluatingJavaScriptFromString:js];
}

@end
