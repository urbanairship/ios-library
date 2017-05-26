/* Copyright 2017 Urban Airship and Contributors */

#import "UAWebViewCallData.h"
#import "NSString+UAURLEncoding.h"

@implementation UAWebViewCallData

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView {
    return [UAWebViewCallData callDataForURL:url webView:webView delegate:nil message:nil];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView message:(UAInboxMessage *)message {
    return [UAWebViewCallData callDataForURL:url webView:webView delegate:nil message:message];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate {
    return [UAWebViewCallData callDataForURL:url webView:nil delegate:delegate message:nil];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate message:(UAInboxMessage *)message {
    return [UAWebViewCallData callDataForURL:url webView:nil delegate:delegate message:message];
}

+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView delegate:(id <UAWKWebViewDelegate>)delegate message:(UAInboxMessage *)message {

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *encodedUrlPath = components.percentEncodedPath;
    if ([encodedUrlPath hasPrefix:@"/"]) {
        encodedUrlPath = [encodedUrlPath substringFromIndex:1]; //trim the leading slash
    }

    // Put the arguments into an array
    // NOTE: we special case an empty array as componentsSeparatedByString
    // returns an array with a copy of the input in the first position when passed
    // a string without any delimiters
    NSArray* arguments;
    if (encodedUrlPath.length) {
        NSArray *encodedArguments = [encodedUrlPath componentsSeparatedByString:@"/"];
        NSMutableArray *decodedArguments = [NSMutableArray arrayWithCapacity:encodedArguments.count];

        for (NSString *encodedArgument in encodedArguments) {
            [decodedArguments addObject:[encodedArgument urlDecodedString]];
        }

        arguments = [decodedArguments copy];
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
