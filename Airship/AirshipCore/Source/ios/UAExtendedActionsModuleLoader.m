/* Copyright Airship and Contributors */

#import "UAExtendedActionsModuleLoader.h"
#import "UAActionRegistry.h"
#import "UAirship.h"
#import "UAExtendedActionsResources.h"

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
