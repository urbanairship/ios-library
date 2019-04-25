/* Copyright Airship and Contributors */

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
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAComponent *location;
@property (nonatomic, strong) NSDictionary<const NSString *, NSString *> *coreModules;
@property (nonatomic, strong) NSDictionary<const NSString *, UAComponent*> *externalModules;
@end

@implementation UAModules

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.location = [self loadExternalModule:@"UALocation" dataStore:dataStore];
        self.externalModules =  [NSMutableDictionary dictionary];
        [self.externalModules setValue:self.location forKey:UAModulesLocation];
    }

    return self;
}

- (UAComponent *)loadExternalModule:(NSString *)className dataStore:(UAPreferenceDataStore *)dataStore {
    Class cls = NSClassFromString(className);
    if ([cls isSubclassOfClass:[UAComponent class]]) {
        UAComponent *component = [(UAComponent *)[cls alloc] initWithDataStore:dataStore];
        return component;
    }
    
    return nil;
}

#pragma mark -
#pragma mark Properties and constants
- (NSDictionary<NSString *, NSString *> *)coreModules {
    if (!_coreModules) {
        _coreModules = @{
                       UAModulesPush : NSStringFromSelector(@selector(sharedPush)),
                       UAModulesAnalytics : NSStringFromSelector(@selector(sharedAnalytics)),
                       UAModulesAutomation : NSStringFromSelector(@selector(sharedAutomation)),
                       UAModulesNamedUser : NSStringFromSelector(@selector(sharedNamedUser)),
#if !TARGET_OS_TV
                       UAModulesMessageCenter : NSStringFromSelector(@selector(sharedInbox)),
                       UAModulesInAppMessaging : NSStringFromSelector(@selector(sharedInAppMessageManager)),
#endif
                       };
    }
    return _coreModules;
}

- (NSArray<NSString *> *)allModuleNames {
    return [self.coreModules.allKeys arrayByAddingObjectsFromArray:self.externalModules.allKeys];
}

- (nullable UAComponent *)airshipComponentForModuleName:(NSString *)moduleName {
    NSString *property = self.coreModules[moduleName];

    if (!property.length) {
        UA_LWARN(@"No module with name: %@", moduleName);
        return nil;
    }

    UAComponent *component = [[UAirship shared] valueForKey:property];

    if (!component) {
        UA_LWARN(@"Unable to create component, no airship property with name: %@", property);
        return nil;
    }

    return component;
}

- (nullable UAComponent *)externalComponentForModuleName:(NSString *)moduleName {
    return [self.externalModules valueForKey:moduleName];
}

- (nullable UAComponent *)componentForModuleName:(NSString *)moduleName {
    if ([self.coreModules.allKeys containsObject:moduleName]) {
        return [self airshipComponentForModuleName:moduleName];
    }

    if ([self.externalModules.allKeys containsObject:moduleName]) {
        return [self.externalModules valueForKey:moduleName];
    }

    UA_LWARN(@"No module with name: %@", moduleName);

    return nil;
}

- (void)processConfigs:(NSDictionary *)configs {
    for (NSString *key in configs) {
        UAComponent *component = [self componentForModuleName:key];

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
