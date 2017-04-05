/* Copyright 2017 Urban Airship and Contributors */

#import "UAWebViewCallData.h"

@implementation UAWebViewCallData

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView {
    return [UAWebViewCallData callDataForURL:url nullableWebView:webView nullableDelegate:nil message:nil];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView message:(UAInboxMessage *)message {
    return [UAWebViewCallData callDataForURL:url nullableWebView:webView nullableDelegate:nil message:message];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate {
    return [UAWebViewCallData callDataForURL:url nullableWebView:nil nullableDelegate:delegate message:nil];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate message:(UAInboxMessage *)message {
    return [UAWebViewCallData callDataForURL:url nullableWebView:nil nullableDelegate:delegate message:message];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url nullableWebView:(UIWebView *)webView nullableDelegate:(id <UAWKWebViewDelegate>)delegate message:(UAInboxMessage *)message {
    
    NSAssert((webView != nil) || (delegate != nil),@"webView (%@) or delegate (%@) must be non-null",webView,delegate);
    
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
    NSArray *queries = [urlQuery componentsSeparatedByString:@"&"];

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
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    data.webView = webView;
#pragma GCC diagnostic pop
    data.delegate = delegate;
    data.url = url;
    data.message = message;

    return data;
}

@end
