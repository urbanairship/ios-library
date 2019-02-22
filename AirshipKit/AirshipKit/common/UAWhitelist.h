/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Scope option for whitelist matching.
 */
typedef NS_OPTIONS(NSUInteger, UAWhitelistScope) {
    /**
     * Applies to the JavaScript Native Bridge interface. This is the de-facto scope
     * prior to SDK 9.
     */
    UAWhitelistScopeJavaScriptInterface = 1 << 0,

    /**
     * Applies to loading or opening of URLs.
     */
    UAWhitelistScopeOpenURL = 1 << 1,

    /**
     * Applies to both the JavaScript interface and loading URLs. This is the default scope unless
     * otherwise specified.
     */
    UAWhitelistScopeAll = UAWhitelistScopeJavaScriptInterface | UAWhitelistScopeOpenURL
};

/**
 * Delegate protocol for accepting and rejecting white-listed URLs.
 */
@protocol UAWhitelistDelegate <NSObject>

///---------------------------------------------------------------------------------------
/// @name Whitelist Delegate Optional Methods
///---------------------------------------------------------------------------------------
@optional

/**
 * Called when a URL has been whitelisted by the SDK, but before the URL is fetched.
 *
 * @param url The URL whitelisted by the SDK.
 * @param scope The scope of the desired match.
 * @return YES to accept whitelisting of this URL, NO to reject whitelisting of this URL.
 */
- (BOOL)acceptWhitelisting:(NSURL *)url scope:(UAWhitelistScope)scope;

@end

/**
 * Class for whitelisting and verifying webview URLs.
 *
 * Whitelist entries are written as URL patterns with optional wildcard matching:
 *
 *     \<scheme\> := \<any char combination, '\*' are treated as wildcards\>
 *
 *     \<host\> := '\*' | '\*.'\<any char combination except '/' and '\*'\> | \<any char combination except '/' and '\*'\>
 *
 *     \<path\> := \<any char combination, '\*' are treated as wildcards\>
 *
 *     \<pattern\> := '\*' | \<scheme\>://\<host\>\<path\> | \<scheme\>://\<host\> | \<scheme\>:/\<path\> | \<scheme\>:///\<path\>
 *
 * A single wildcard will match any URI.
 * Wildcards in the scheme pattern will match any characters, and a single wildcard in the scheme will match any scheme.
 * The wildcard in a host pattern "*.mydomain.com" will match anything within the mydomain.com domain.
 * Wildcards in the path pattern will match any characters, including subdirectories.
 *
 * Note that NSURL does not support internationalized domains containing non-ASCII characters.
 * All whitelist entries for internationalized domains must be in ASCII IDNA format as
 * specified in https://tools.ietf.org/html/rfc3490
 */
@interface UAWhitelist : NSObject

///---------------------------------------------------------------------------------------
/// @name Whitelist Properties
///---------------------------------------------------------------------------------------

/**
 * Enables or disables whitelist checks at the scope `UAWhitelistScopeOpenURL`. If disabled,
 * all whitelist checks for this scope will be allowed.
 */
@property(nonatomic, assign, getter=isOpenURLWhitelistingEnabled) BOOL openURLWhitelistingEnabled;

/**
 * The whitelist delegate.
 * NOTE: The delegate is not retained.
 */
@property (nonatomic, weak, nullable) id <UAWhitelistDelegate> delegate;

///---------------------------------------------------------------------------------------
/// @name Whitelist Creation
///---------------------------------------------------------------------------------------

/**
 * Create a default whitelist with entries specified in a config object.
 * @note The entry "*.urbanairship.com" is added by default.
 * @param config An instance of UAConfig.
 * @return An instance of UAWhitelist
 */
+ (instancetype)whitelistWithConfig:(UAConfig *)config;

///---------------------------------------------------------------------------------------
/// @name Whitelist Core Methods
///---------------------------------------------------------------------------------------

/**
 * Add an entry to the whitelist, with the implicit scope `UAWhitelistScopeAll`.
 * @param patternString A whitelist pattern string.
 * @return `YES` if the whitelist pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString;

/**
 * Add an entry to the whitelist.
 * @param patternString A whitelist pattern string.
 * @param scope The scope of the pattern.
 * @return `YES` if the whitelist pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString scope:(UAWhitelistScope)scope;

/**
 * Determines whether a given URL is whitelisted, with the implicit scope `UAWhitelistScopeAll`.
 * @param url The URL under consideration.
 * @return `YES` if the the URL is whitelisted, `NO` otherwise.
 */
- (BOOL)isWhitelisted:(NSURL *)url;

/**
 * Determines whether a given URL is whitelisted.
 * @param url The URL under consideration.
 * @param scope The scope of the desired match.
 * @return `YES` if the the URL is whitelisted, `NO` otherwise.
 */
- (BOOL)isWhitelisted:(NSURL *)url scope:(UAWhitelistScope)scope;

@end

NS_ASSUME_NONNULL_END
