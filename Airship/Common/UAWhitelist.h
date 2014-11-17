

#import <Foundation/Foundation.h>

@class UAConfig;

/**
 * Class for whitelisting and verifying webview URLs.
 *
 * Whitelist entries are written as URL patterns with optional wildcard matching:
 *
 * <scheme> := '*' | 'http' | 'https'
 * <host> := '*' | '*.'<any char except '/' and '*'> | <any char except '/' and '*'>
 * <path> := '/' <any chars, including *>
 * <pattern> := '*' | <scheme>://<host><path> | <scheme>://<host> | file://<path>
 *
 * e.g. "http://server.mydomain.com/something.html"
 *      "https://*.mydomain.com"
 *      "*://*.mydomain.com/foo/bar/*"
 */
@interface UAWhitelist : NSObject

/**
 * Create a default whitelist with entries specified in a config object.
 * @param config An instance of UAConfig.
 */
+ (instancetype)whitelistWithConfig:(UAConfig *)config;

/**
 * Add an entry to the whitelist.
 * @param patternString A whitelist pattern string.
 * @return `YES` is the whitelist pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString;
/**
 * Determines whether a given URL is whitelisted.
 * @retrn `YES` if the the URL is whitelisted, `NO` otherwise.
 */
- (BOOL)isWhitelisted:(NSURL *)url;

@end
