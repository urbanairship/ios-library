/* Copyright Urban Airship and Contributors */

#import "UAModules+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"

NSString * const UAModulesPush = @"push";
NSString * const UAModulesAnalytics = @"analytics";
NSString * const UAModulesMessageCenter = @"message_center";
NSString * const UAModulesInAppMessaging = @"in_app_v2";
NSString * const UAModulesAutomation = @"automation";
NSString * const UAModulesNamedUser = @"named_user";
NSString * const UAModulesLocation = @"location";

@interface UAModules ()
@property (nonatomic, strong) NSDictionary<const NSString *, NSString *> *moduleMap;
@end

@implementation UAModules

#pragma mark -
#pragma mark Properties and constants
- (NSDictionary<NSString *, NSString *> *)moduleMap {
    if (!_moduleMap) {
        _moduleMap = @{
                       UAModulesPush:NSStringFromSelector(@selector(sharedPush)),
                       UAModulesAnalytics:NSStringFromSelector(@selector(sharedAnalytics)),
                       UAModulesAutomation:NSStringFromSelector(@selector(sharedAutomation)),
                       UAModulesNamedUser:NSStringFromSelector(@selector(sharedNamedUser)),
                       UAModulesLocation:NSStringFromSelector(@selector(sharedLocation)),
#if !TARGET_OS_TV
                       UAModulesMessageCenter:NSStringFromSelector(@selector(sharedInbox)),
                       UAModulesInAppMessaging:NSStringFromSelector(@selector(sharedInAppMessageManager)),
#endif
                       };
    }
    return _moduleMap;
}

- (NSArray<NSString *> *)allModuleNames {
    return self.moduleMap.allKeys;
}

- (nullable UAComponent *)airshipComponentForModuleName:(NSString *)moduleName {
    NSString *airshipProperty = self.moduleMap[moduleName];
    if (!airshipProperty.length) {
        UA_LWARN(@"No module with name: %@", moduleName);
        return nil;
    }

    UAComponent *component = [[UAirship shared] valueForKey:airshipProperty];

    if (!component) {
        UA_LWARN(@"Unable to create component, no airship property with name: %@", airshipProperty);
        return nil;
    }

    return component;
}

- (void)processConfigs:(NSDictionary *)configs {
    for (NSString *key in configs) {
        UAComponent *component = [self airshipComponentForModuleName:key];

        if (!component) {
            continue;
        }

        NSArray *payloads = configs[key];

        UARemoteConfig *combinedConfig;

        for (UARemoteDataPayload *payload in payloads) {
            Class remoteConfigClass = component.remoteConfigClass;
            if (!remoteConfigClass) {
                UA_LERR(@"Unable to get remote config class for module name: %@, payload: %@", key, payload);
                continue;
            }
            
            UARemoteConfig *config = [remoteConfigClass configWithJSON:payload.data];

            if (!config) {
                UA_LERR(@"Unable to produce config for module name: %@, payload: %@", key, payload);
                continue;
            }

            combinedConfig = [config combineWithConfig:combinedConfig];
        }

        if (combinedConfig) {
            [component onNewRemoteConfig:combinedConfig];
        } else {
            UA_LERR(@"Unable to produce combined config for module: %@", key);
        }
    }
}

@end
