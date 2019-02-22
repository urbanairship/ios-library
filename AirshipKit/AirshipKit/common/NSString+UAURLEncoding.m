/* Copyright Urban Airship and Contributors */

#import "NSString+UAURLEncoding.h"

@implementation NSString(UAURLEncoding)

- (nullable NSString *)urlDecodedString {
    return [self stringByRemovingPercentEncoding];
}

- (nullable NSString *)urlEncodedString {
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}

@end
