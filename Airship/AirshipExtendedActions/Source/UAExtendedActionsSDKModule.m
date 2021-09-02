/* Copyright Airship and Contributors */

#import "UAExtendedActionsSDKModule.h"
#import "UAExtendedActionsResources.h"
#import "UAExtendedActionsCoreImport.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation UAExtendedActionsSDKModule

+ (id<UASDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    return [[self alloc] init];
}

- (NSString *)actionsPlist {
    return [[UAExtendedActionsResources bundle] pathForResource:@"UAExtendedActions" ofType:@"plist"];
}

@end
