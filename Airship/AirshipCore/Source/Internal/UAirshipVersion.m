/* Copyright Airship and Contributors */

#import "UAirshipVersion.h"

static NSString *const versionString = @"14.3.1";

@implementation UAirshipVersion

+ (nonnull NSString *)get {
    return versionString;
}

@end
