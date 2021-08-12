/* Copyright Airship and Contributors */

#import "UAExtendedActionsModuleLoader.h"
#import "UAExtendedActionsResources.h"
#import "UAExtendedActionsCoreImport.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation UAExtendedActionsModuleLoader

+ (instancetype)extendedActionsModuleLoader {
    return [[self alloc] init];
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSString *path = [[UAExtendedActionsResources bundle] pathForResource:@"UAExtendedActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}

@end
