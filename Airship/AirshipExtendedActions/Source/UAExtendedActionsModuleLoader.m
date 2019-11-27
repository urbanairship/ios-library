/* Copyright Airship and Contributors */

#import "UAExtendedActionsModuleLoader.h"
#import "UAExtendedActionsResources.h"

#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
#else
#import "UAActionRegistry.h"
#import "UAirship.h"
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
