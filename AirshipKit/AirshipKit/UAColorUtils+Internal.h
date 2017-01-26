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
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A collection of utilities for converting UIColors to and from various string representations.
 */
@interface UAColorUtils : NSObject

/**
 * Converts a hex color string of type #aarrggbb or
 * #rrggbb into a UIColor.
 *
 * @param hexString A hex color string of type #aarrggbb or
 * #rrggbb.
 * @return An instance of UIColor, or `nil` if the color could
 * not be correctly parsed.
 */
+ (nullable UIColor *)colorWithHexString:(NSString *)hexString;

/**
 * Converts a UIColor into a hex color string of type #aarrggbb.
 *
 * @param color An instance of UIColor.
 * @return An NSString of type #aarrggbb representing the passed color, or
 * nil if the UIColor cannot be converted to the RGBA colorspace.
 */
+ (nullable NSString *)hexStringWithColor:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
