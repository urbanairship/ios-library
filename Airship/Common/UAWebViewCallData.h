
#import <Foundation/Foundation.h>

/**
 * Model object for holding data associated with JS delegate calls 
 */
@interface UAWebViewCallData : NSObject

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param url The URL to be processed.
 * @param webView The UIWebView originating the call
 * @return An instance of UAWebViewCallData.
 */
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView;

/**
 * A name, derived from the host passed in the delegate call URL.
 * This is typically the name of a command.
 */
@property(nonatomic, strong) NSString *name;

/**
 * The argument strings passed in the call.
 */
@property(nonatomic, strong) NSArray *arguments;

/**
 * The query options passed in the call.
 */
@property(nonatomic, strong) NSDictionary *options;

/**
 * The UIWebView initiating the call;
 */
@property(nonatomic, strong) UIWebView *webView;

@end
