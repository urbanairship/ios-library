/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

@class UAConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Class for whitelisting and verifying webview URLs.
 *
 * Whitelist entries are written as URL patterns with optional wildcard matching:
 *
 *     \<scheme\> := '\*' | 'http' | 'https'
 *
 *     \<host\> := '\*' | '\*.'\<any char except '/' and '\*'\> | \<any char except '/' and '\*'\>
 *
 *     \<path\> := '/' \<any chars, including \*\>
 *
 *     \<pattern\> := '\*' | \<scheme\>://\<host\>\<path\> | \<scheme\>://\<host\> | file://\<path\>
 *
 * Wildcards in the scheme pattern will match either http or https schemes.
 * The wildcard in a host pattern "*.mydomain.com" will match anything within the mydomain.com domain.
 * Wildcards in the path pattern will match any characters, including subdirectories.
 *
 * Note that NSURL does not support internationalized domains containing non-ASCII characters.
 * All whitelist entries for internationalized domains must be in ASCII IDNA format as
 * specified in https://tools.ietf.org/html/rfc3490
 */
@interface UAWhitelist : NSObject

/**
 * Create a default whitelist with entries specified in a config object.
 * @note The entry "*.urbanairship.com" is added by default.
 * @param config An instance of UAConfig.
 * @return An instance of UAWhitelist
 */
+ (instancetype)whitelistWithConfig:(UAConfig *)config;

/**
 * Add an entry to the whitelist.
 * @param patternString A whitelist pattern string.
 * @return `YES` if the whitelist pattern was validated and added, `NO` otherwise.
 */
- (BOOL)addEntry:(NSString *)patternString;
/**
 * Determines whether a given URL is whitelisted.
 * @param url The URL under consideration.
 * @return `YES` if the the URL is whitelisted, `NO` otherwise.
 */
- (BOOL)isWhitelisted:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
