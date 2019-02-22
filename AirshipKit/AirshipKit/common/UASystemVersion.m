/* Copyright Urban Airship and Contributors */
#import "UAUtils+Internal.h"
#import "UASystemVersion+Internal.h"

@implementation UASystemVersion

+ (instancetype)systemVersion {
    return [[self alloc] init];
}

- (NSString *)currentSystemVersion {
    return UIDevice.currentDevice.systemVersion;
}

- (BOOL)isGreaterOrEqualToVersion:(NSString *)version {
    NSString *systemVersion = [self currentSystemVersion];

    NSComparisonResult result = [systemVersion compare:version options:NSNumericSearch];

    return result == NSOrderedSame || result == NSOrderedDescending;
}

@end
