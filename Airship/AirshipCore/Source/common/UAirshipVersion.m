/* Copyright Airship and Contributors */

#import "UAirshipVersion.h"

static NSString *const versionString = @"13.3.1";

@implementation UAirshipVersion

+ (nonnull NSString *)get {
    return versionString;
}

@end
