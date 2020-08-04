/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Scope option for URL allow list matching.
 */
typedef NS_OPTIONS(NSUInteger, UAURLAllowListScope) {
    /**
     * Applies to the JavaScript Native Bridge interface. This is the de-facto scope
     * prior to SDK 9.
     */
    UAURLAllowListScopeJavaScriptInterface = 1 << 0,

    /**
     * Applies to loading or opening of URLs.
     */
    UAURLAllowListScopeOpenURL = 1 << 1,

    /**
     * Applies to both the JavaScript interface and loading URLs. This is the default scope unless
     * otherwise specified.
     */
    UAURLAllowListScopeAll = UAURLAllowListScopeJavaScriptInterface | UAURLAllowListScopeOpenURL
};

/**
 * Delegate protocol for accepting and rejecting URLs.
 */
@protocol UAURLAllowListDelegate <NSObject>

///---------------------------------------------------------------------------------------
/// @name URL allow list Delegate Optional Methods
///---------------------------------------------------------------------------------------
@optional

/**
 * Called when a URL has been allowed by the SDK, but before the URL is fetched.
 *
 * @param URL The URL allowed by the SDK.
 * @param scope The scope of the desired match.
 * @return YES to accept this URL, NO to reject this URL.
 */
- (BOOL)allowURL:(NSURL *)URL scope:(UAURLAllowListScope)scope;

@end

/**
 * Class for accepting and verifying webview URLs.
 *
 * URL allow list entries are written as URL patterns with optional wildcard matching:
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
 * All URL allow list entries for internationalized domains must be in ASCII IDNA format as
 * specified in https://tools.ietf.org/html/rfc3490
 */
@interface UAURLAllowList : NSObject

///---------------------------------------------------------------------------------------
/// @name URL Allow list Properties
///---------------------------------------------------------------------------------------

/**
 * The URL allow list delegate.
 * NOTE: The delegate is not retained.
 */
@property (nonatomic, weak, nullable) id <UAURLAllowListDelegate> delegate;

///---------------------------------------------------------------------------------------
/// @name URL Allow list Creation
///---------------------------------------------------------------------------------------

/**
 * Create a default URL allow list with entries specified in a config object.
 * @note The entry "*.urbanairship.com" is added by default.
 * @param config An instance of UARuntimeConfig.
 * @return An instance of UAURLAllowList
 */
+ (instancetype)allowListWithConfig:(UARuntimeConfig *)config;

///---------------------------------------------------------------------------------------
/// @name URL allow list Core Methods
///---------------------------------------------------------------------------------------

/**
 * Add an entry to the URL allow list, with the implicit scope `UAURLAllowListScopeAll`.
 * @param patternString A URL allow list pattern string.
 * @return `YES` if the URL allow list pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString;

/**
 * Add an entry to the URL allow list.
 * @param patternString A URL allow list pattern string.
 * @param scope The scope of the pattern.
 * @return `YES` if the URL allow list pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString scope:(UAURLAllowListScope)scope;

/**
 * Determines whether a given URL is allowed, with the implicit scope `UAURLAllowListScopeAll`.
 * @param URL The URL under consideration.
 * @return `YES` if the the URL is allowed, `NO` otherwise.
 */
- (BOOL)isAllowed:(NSURL *)URL;

/**
 * Determines whether a given URL is allowed.
 * @param URL The URL under consideration.
 * @param scope The scope of the desired match.
 * @return `YES` if the the URL is allowed, `NO` otherwise.
 */
- (BOOL)isAllowed:(NSURL *)URL scope:(UAURLAllowListScope)scope;

@end

NS_ASSUME_NONNULL_END
