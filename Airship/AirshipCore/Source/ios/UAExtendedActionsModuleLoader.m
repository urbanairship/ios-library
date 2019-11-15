/* Copyright Airship and Contributors */

#import "UAExtendedActionsModuleLoader.h"
#import "UAActionRegistry.h"
#import "UAirship.h"

@implementation UAExtendedActionsModuleLoader

+ (instancetype)extendedActionsModuleLoader {
    return [[self alloc] init];
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSString *path = [[UAirship resources] pathForResource:@"UAExtendedActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}

@end
