/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

#define kUACacheMemorySizeInBytes  5 * 1024 * 1024 // 5 MB

NS_ASSUME_NONNULL_BEGIN

/**
 * A NSURLProtocol that caches successful responses to requests
 * who's URL or mainDocumentURL has been added as a cachableURL.
 * A failed response will always fall back to a cached response 
 * when available.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. The UAURLProtocol is obsolete with the use of WKWebView.
 */
DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. The UAURLProtocol is obsolete with the use of WKWebView")
@interface UAURLProtocol : NSURLProtocol

///---------------------------------------------------------------------------------------
/// @name URL Protocol Core Methods
///---------------------------------------------------------------------------------------

/**
 * Adds a URL to be handled and cached by the Protocol.
 *
 * @param url The URL or mainDocumentURL of a request to cache.
 */
+ (void)addCachableURL:(NSURL *)url;

/**
 * Removes a URL from being cached.
 *
 * @param url The URL or mainDocumentURL of a request.
 */
+ (void)removeCachableURL:(NSURL *)url;

/**
 * Clears the URL cache
 */
+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
