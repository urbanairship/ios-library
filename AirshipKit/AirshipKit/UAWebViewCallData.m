/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UAWebViewCallData.h"

@implementation UAWebViewCallData

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView {
    return [UAWebViewCallData callDataForURL:url webView:webView message:nil];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView message:(UAInboxMessage *)message {
    NSString *urlPath = [url path];
    if ([urlPath hasPrefix:@"/"]) {
        urlPath = [urlPath substringFromIndex:1]; //trim the leading slash
    }

    // Put the arguments into an array
    // NOTE: we special case an empty array as componentsSeparatedByString
    // returns an array with a copy of the input in the first position when passed
    // a string without any delimiters
    NSArray* arguments;
    if ([urlPath length] > 0) {
        arguments = [urlPath componentsSeparatedByString:@"/"];
    } else {
        arguments = [NSArray array];//empty
    }

    // Dictionary of options - primitive parsing, so external docs should mention the limitations
    NSString *urlQuery = [url query];
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    NSArray * queries = [urlQuery componentsSeparatedByString:@"&"];

    for (int i = 0; i < [queries count]; i++) {
        NSArray *optionPair = [[queries objectAtIndex:(NSUInteger)i] componentsSeparatedByString:@"="];
        NSString *key = [optionPair objectAtIndex:0];
        NSString *object = (optionPair.count >= 2) ? [optionPair objectAtIndex:1] : [NSNull null];


        NSMutableArray *values = [options valueForKey:key];
        if (!values) {
            values = [NSMutableArray array];
            [options setObject:values forKey:key];
        }

        [values addObject:object];
    }

    UAWebViewCallData *data = [[UAWebViewCallData alloc] init];

    data.name = url.host;
    data.arguments = arguments;
    data.options = options;
    data.webView = webView;
    data.url = url;
    data.message = message;

    return data;
}

@end
