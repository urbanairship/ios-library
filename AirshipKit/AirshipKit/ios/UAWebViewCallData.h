/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UAWKWebViewDelegate.h"

@class UAInboxMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for holding data associated with JS delegate calls 
 */
@interface UAWebViewCallData : NSObject

///---------------------------------------------------------------------------------------
/// @name Web View Call Data Properties
///---------------------------------------------------------------------------------------

/**
 * A name, derived from the host passed in the delegate call URL.
 * This is typically the name of a command.
 */
@property (nonatomic, copy, nullable) NSString *name;

/**
 * The argument strings passed in the call.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *> *arguments;

/**
 * The query options passed in the call.
 */
@property (nonatomic, strong, nullable) NSDictionary *options;

/**
 * The UAWKWebViewDelegate for the webview initiating the call.
 */
@property (nonatomic, weak, nullable) id <UAWKWebViewDelegate> delegate;

/**
 * The orignal URL that initiated the call.
 */
@property (nonatomic, strong) NSURL *url;

/**
 * The UAInboxMessage associated with the webview.
 */
@property (nonatomic, strong, nullable) UAInboxMessage *message;

///---------------------------------------------------------------------------------------
/// @name Web View Call Data Core Methods
///---------------------------------------------------------------------------------------

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param url The URL to be processed.
 * @param delegate The UAWKWebViewDelegate delegate for the webview originating the call
 * @return An instance of UAWebViewCallData.
 */
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate ;

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param url The URL to be processed.
 * @param delegate The UAWKWebViewDelegate delegate for the webview originating the call
 * @param message The UAInboxMessage associated with the webview.
 * @return An instance of UAWebViewCallData.
 */
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url delegate:(id <UAWKWebViewDelegate>)delegate message:(nullable UAInboxMessage *)message;

@end

NS_ASSUME_NONNULL_END
