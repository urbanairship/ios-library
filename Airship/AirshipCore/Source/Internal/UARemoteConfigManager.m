/* Copyright Airship and Contributors */

#import "UARemoteConfigManager+Internal.h"
#import "UADisposable.h"
#import "UAirshipVersion.h"
#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAApplicationMetrics.h"
#import "UARemoteConfigDisableInfo+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"
#import "UARemoteConfig.h"
#import "UAUtils.h"

NSString * const UAAppConfigCommon = @"app_config";
NSString * const UAAppConfigIOS = @"app_config:ios";

// Disable config key
NSString * const UARemoteConfigDisableKey = @"disable_features";
// Airship config key
NSString * const UAAirshipConfigKey = @"airship_config";

// Notifications
NSString * const UAAirshipRemoteConfigUpdatedEvent = @"com.urbanairship.airship_remote_config_updated";
NSString * const UAAirshipRemoteConfigUpdatedKey = @"com.urbanairship.airship_remote_config_updated_key";

@interface UARemoteConfigManager()
@property (nonatomic, strong) UADisposable *remoteDataSubscription;
@property (nonatomic, strong) UARemoteConfigModuleAdapter *moduleAdapter;
@property (nonatomic, strong) UARemoteDataManager *remoteDataManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, copy) NSString *(^versionBlock)(void);

@end

@implementation UARemoteConfigManager

+ (instancetype)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                          privacyManager:(UAPrivacyManager *)privacyManager {

    return [[UARemoteConfigManager alloc] initWithRemoteDataManager:remoteDataManager
                                                     privacyManager:privacyManager
                                                      moduleAdapter:[[UARemoteConfigModuleAdapter alloc] init]
                                                       versionBlock:^NSString *{
        return [UAUtils bundleShortVersionString];
    }];
}

+ (instancetype)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                          privacyManager:(UAPrivacyManager *)privacyManager
                                           moduleAdapter:(UARemoteConfigModuleAdapter *)moduleAdapter
                                            versionBlock:(NSString *(^)(void))versionBlock {

    return [[UARemoteConfigManager alloc] initWithRemoteDataManager:remoteDataManager
                                                     privacyManager:privacyManager
                                                      moduleAdapter:moduleAdapter
                                                       versionBlock:versionBlock];
}

- (instancetype)initWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                           privacyManager:(UAPrivacyManager *)privacyManager
                            moduleAdapter:(UARemoteConfigModuleAdapter *)moduleAdapter
                             versionBlock:(NSString *(^)(void))versionBlock {


    self = [super init];

    if (self) {
        self.remoteDataManager = remoteDataManager;
        self.privacyManager = privacyManager;
        self.moduleAdapter = moduleAdapter;
        self.versionBlock = versionBlock;

        [self updateRemoteConfigSubscription];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateRemoteConfigSubscription)
                                                     name:UAPrivacyManagerEnabledFeaturesChangedEvent
                                                   object:nil];
    }

    return self;
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)processRemoteConfig:(NSArray<UARemoteDataPayload *> *)payloads {
    // Combine the data
    NSMutableDictionary *combinedData = [NSMutableDictionary dictionary];
    for (UARemoteDataPayload *payload in payloads) {
        [combinedData addEntriesFromDictionary:payload.data];
    }

    // Disable features
    [self applyDisableInfosFromRemoteData:combinedData];

    // Module config
    [self applyConfigsFromRemoteData:combinedData];

    //Remote config
    [self applyRemoteConfigFromRemoteData:combinedData];
}

- (void)applyDisableInfosFromRemoteData:(NSDictionary *)data {
    id disableJSONArray = data[UARemoteConfigDisableKey];
    if (!disableJSONArray) {
        return;
    }

    if (![disableJSONArray isKindOfClass:[NSArray class]]) {
        UA_LERR("Invalid disable info: %@", disableJSONArray);
        return;
    }

    // Parse the disable info
    NSMutableArray *disableInfos = [NSMutableArray array];
    for (id disableJSON in disableJSONArray) {
        UARemoteConfigDisableInfo *disableInfo = [UARemoteConfigDisableInfo disableInfoWithJSON:disableJSON];
        if (!disableInfo) {
            UA_LERR("Invalid disable info: %@", disableJSON);
            continue;
        }
        [disableInfos addObject:disableInfo];
    }

    // Filter out any that do not apply
    NSArray *filteredDisableInfos = [UARemoteConfigManager filterDisableInfos:disableInfos
                                                                   sdkVersion:[UAirshipVersion get]
                                                                   appVersion:self.versionBlock()];

    NSMutableSet<NSString *> *disableModuleNames = [NSMutableSet set];
    NSTimeInterval remoteDataRefreshInterval = UARemoteDataRefreshIntervalDefault;

    // Pass through all the filtered disable info to find the disabled modules and the max remote data refresh
    for (UARemoteConfigDisableInfo *disableInfo in filteredDisableInfos) {
        [disableModuleNames addObjectsFromArray:disableInfo.disableModuleNames];
        if (disableInfo.remoteDataRefreshInterval) {
            remoteDataRefreshInterval = MAX([disableInfo.remoteDataRefreshInterval unsignedIntegerValue], remoteDataRefreshInterval);
        }
    }

    // Disable modules
    for (NSString *moduleID in disableModuleNames) {
        [self.moduleAdapter setComponentsEnabled:NO forModuleName:moduleID];
    }

    // Enable modules
    NSMutableSet<NSString *> *enableModulesNames = [NSMutableSet setWithArray:kUARemoteConfigModuleAllModules];
    [enableModulesNames minusSet:disableModuleNames];
    for (NSString *moduleID in enableModulesNames) {
        [self.moduleAdapter setComponentsEnabled:YES forModuleName:moduleID];
    }

    // Update remote data refresh interval
    self.remoteDataManager.remoteDataRefreshInterval = remoteDataRefreshInterval;
}

- (void)applyConfigsFromRemoteData:(NSDictionary *)data {
    for (NSString *moduleName in kUARemoteConfigModuleAllModules) {
        [self.moduleAdapter applyConfig:data[moduleName] forModuleName:moduleName];
    }
}

- (void)applyRemoteConfigFromRemoteData:(NSDictionary *)data {
    NSDictionary *remoteConfigData = data[UAAirshipConfigKey];
    if (!remoteConfigData) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:UAAirshipRemoteConfigUpdatedEvent object:nil userInfo:@{UAAirshipRemoteConfigUpdatedKey: remoteConfigData}];
}

+ (NSArray<UARemoteConfigDisableInfo *> *)filterDisableInfos:(NSArray<UARemoteConfigDisableInfo *> *)disableInfos
                                                  sdkVersion:(NSString *)sdkVersion
                                                  appVersion:(NSString *)appVersion {

    id versionObject = @{ @"ios" : @{ @"version": appVersion } };

    return [disableInfos filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        UARemoteConfigDisableInfo *disableInfo = (UARemoteConfigDisableInfo *)object;

        if (disableInfo.appVersionConstraint && ![disableInfo.appVersionConstraint evaluateObject:versionObject]) {
            return NO;
        }

        if (disableInfo.sdkVersionConstraints.count) {
            BOOL sdkVersionMatch = NO;
            for (UAVersionMatcher *sdkVersionMatcher in disableInfo.sdkVersionConstraints) {
                if ([sdkVersionMatcher evaluateObject:sdkVersion]) {
                    sdkVersionMatch = YES;
                    break;
                }
            }

            if (!sdkVersionMatch) {
                return NO;
            }
        }

        return YES;
    }]];
}

- (void)updateRemoteConfigSubscription {
    if ([self.privacyManager isAnyFeatureEnabled] && !self.remoteDataSubscription) {
        self.remoteDataSubscription = [self.remoteDataManager subscribeWithTypes:@[UAAppConfigCommon, UAAppConfigIOS]
                                                                           block:^(NSArray<UARemoteDataPayload *> *remoteConfig) {
            [self processRemoteConfig:remoteConfig];
        }];
    } else {
        [self.remoteDataSubscription dispose];
        self.remoteDataSubscription = nil;
    }
}

@end
