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

#import "UAColorUtils+Internal.h"
#import "UAGlobal.h"

@implementation UAColorUtils

+ (UIColor *)colorWithHexString:(NSString *)hexString {

    if (!hexString) {
        return nil;
    }

    hexString = [hexString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }

    NSUInteger width = 8 * (hexString.length /2);
    if (width != 32 && width != 24) {
        UA_LDEBUG(@"Invalid hex color string: %@ (must be 24 or 32 bits wide)", hexString);
        return nil;
    }

    unsigned int component = 0;

    NSScanner *scanner = [NSScanner scannerWithString:hexString];

    if (![scanner scanHexInt:&component]) {
        UA_LDEBUG(@"Unable to scan hexString: %@", hexString);
        return nil;
    };

    return [UIColor colorWithRed:((component & 0xFF0000) >> 16)/255.0
                           green:((component & 0xFF00) >> 8)/255.0
                            blue:(component & 0xFF)/255.0
                           alpha:width == 24 ? 1.0 : ((component & 0xFF000000) >> 24)/255.0];
}

+ (NSString *)hexStringWithColor:(UIColor *)color {
    if (!color) {
        return nil;
    }

    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;

    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        UA_LDEBUG(@"Unable to convert color %@ to RGBA colorspace", color);
        return nil;
    };

    int a, r, g, b;

    r = (int)(255.0 * red);
    g = (int)(255.0 * green);
    b = (int)(255.0 * blue);
    a = (int)(255.0 * alpha);

    return [NSString stringWithFormat:@"#%02x%02x%02x%02x", a, r, g, b];
}

@end
