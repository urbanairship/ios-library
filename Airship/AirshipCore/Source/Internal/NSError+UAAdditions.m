/* Copyright Airship and Contributors */

#import "NSError+UAAdditions.h"


#define kUAParseErrorDomain @"com.urbanairship.parse"
#define kUAParseErrorCode 1

@implementation NSObject(UAAdditions)

+ (NSError *)airshipParseErrorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:kUAParseErrorDomain
                               code:kUAParseErrorCode
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}

@end
