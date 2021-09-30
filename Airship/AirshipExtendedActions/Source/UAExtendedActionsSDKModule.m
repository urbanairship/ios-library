/* Copyright Airship and Contributors */

#import "UAExtendedActionsSDKModule.h"
#import "UAExtendedActionsResources.h"
#import "UAExtendedActionsCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@implementation UAExtendedActionsSDKModule

+ (id<UASDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    return [[self alloc] init];
}

- (NSString *)actionsPlist {
    return [[UAExtendedActionsResources bundle] pathForResource:@"UAExtendedActions" ofType:@"plist"];
}

@end
