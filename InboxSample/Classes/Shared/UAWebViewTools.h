//
//  UAWebViewTools.h
//  InboxSampleLib
//
//  Created by Jeff Towle on 10/8/13.
//
//

#import <Foundation/Foundation.h>

@interface UAWebViewTools : NSObject

+ (NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url;
+ (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;

@end
