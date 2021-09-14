/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

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
} NS_SWIFT_NAME(URLAllowListScope);
