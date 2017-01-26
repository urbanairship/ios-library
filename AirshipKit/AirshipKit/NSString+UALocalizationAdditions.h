/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

@interface NSString (UALocalizationAdditions)


/**
 * Returns a localized string associated to the receiver by the given table, returning the receiver if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipResources,
 * allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param defaultValue The default value.
 * @return The localized string corresponding to the key and table, or the default value if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table defaultValue:(NSString *)defaultValue;

/**
 * Returns a localized string associated to the receiver by the given table, returning the receiver if the
 * string cannot be found. This method searches the main bundle before falling back on AirshipResources,
 * allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @return The localized string corresponding to the key and table, or the key if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table;

/**
 * Returns a localized string associated to the receiver by the given table, falling back on the provided
 * locale and finally the receiver if the string cannot be found. This method searches the main bundle before
 * falling back on AirshipResources, allowing for developers to override or supplement any officially bundled localizations.
 *
 * @param table The table.
 * @param fallbackLocale The locale to use in case a localized string for the current locale cannot be found.
 * @return The localized string corresponding to the key and table, or the key if it cannot be found.
 */
- (NSString *)localizedStringWithTable:(NSString *)table fallbackLocale:(NSString *)fallbackLocale;

@end
