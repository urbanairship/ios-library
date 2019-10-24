/* Copyright Airship and Contributors */

#import "UARemoteConfigModuleAdapter+Internal.h"
#import "UAirship+Internal.h"
#import "UAComponent+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"

NSString * const UALocationClassName = @"UALocation";

@implementation UARemoteConfigModuleAdapter

- (NSArray *)componentsForModuleName:(NSString *)moduleName {
    if ([moduleName isEqualToString:kUARemoteConfigModulePush]) {
        return @[[UAirship push]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleNamedUser]) {
           return @[[UAirship namedUser]];
       }

    if ([moduleName isEqualToString:kUARemoteConfigModuleAnalytics]) {
        return @[[UAirship analytics]];
    }

    #if !TARGET_OS_TV  // Inbox and IAM not available on tvOS
    if ([moduleName isEqualToString:kUARemoteConfigModuleMessageCenter]) {
        return @[[UAirship messageCenter]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleInAppMessaging]) {
        return @[[UAirship inAppMessageManager], [UAirship legacyInAppMessaging]];
    }
    #endif

    if ([moduleName isEqualToString:kUARemoteConfigModuleAutomation]) {
        return @[[UAirship automation]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleLocation]) {
        return @[[[UAirship shared] componentForClassName:UALocationClassName]];
    }

    return @[];
}

- (void)setComponentsEnabled:(BOOL)enabled forModuleName:(NSString *)moduleName {
    NSArray *components = [self componentsForModuleName:moduleName];
    for (UAComponent *component in components) {
        [component setComponentEnabled:enabled];
    }
}

- (void)applyConfig:(nullable id)config forModuleName:(NSString *)moduleName {
    NSArray *components = [self componentsForModuleName:moduleName];
    for (UAComponent *component in components) {
        [component applyRemoteConfig:config];
    }
}

@end
