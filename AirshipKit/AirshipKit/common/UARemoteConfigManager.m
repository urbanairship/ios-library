/* Copyright Urban Airship and Contributors */

#import "UARemoteConfigManager+Internal.h"
#import "UADisposable.h"
#import "UAirship+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAComponentDisabler+Internal.h"

NSString * const UAAppConfigCommon = @"app_config";
NSString * const UAAppConfigIOS = @"app_config:ios";
NSString * const UARemoteConfigDisableKey = @"disable_features";

@interface UARemoteConfigManager()
@property (nonatomic, strong) UADisposable *remoteDataSubscription;
@property (nonatomic, strong) UAComponentDisabler *componentDisabler;
@property (nonatomic, strong) UAModules *modules;
@end

@implementation UARemoteConfigManager

+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                                                  componentDisabler:(UAComponentDisabler *)componentDisabler
                                                            modules:(UAModules *)modules {

    return [[UARemoteConfigManager alloc] initWithRemoteDataManager:remoteDataManager componentDisabler:componentDisabler modules:modules];
}

- (instancetype)initWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager
                        componentDisabler:(UAComponentDisabler *)componentDisabler
                                  modules:(UAModules *)modules {

    self = [super init];
    
    if (self) {
        self.componentDisabler = componentDisabler;
        self.remoteDataSubscription = [remoteDataManager subscribeWithTypes:@[UAAppConfigCommon, UAAppConfigIOS]
                                                                               block:^(NSArray<UARemoteDataPayload *> *remoteConfig) {
                                                                                   [self processRemoteConfig:remoteConfig];
                                                                               }];
        self.modules = modules;
    }
    
    return self;
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)processRemoteConfig:(NSArray<UARemoteDataPayload *> *)remoteConfig {
    NSMutableArray *disableInfos = [NSMutableArray array];
    NSMutableDictionary *configs = [NSMutableDictionary dictionary];

    for (UARemoteDataPayload *payload in remoteConfig) {
        for (NSString *key in payload.data) {
            if ([key isEqualToString:UARemoteConfigDisableKey]) {
                [disableInfos addObjectsFromArray:payload.data[UARemoteConfigDisableKey]];
            } else {
                if (!configs[key]) {
                    [configs setObject:[NSMutableArray array] forKey:key];
                }

                [configs[key] addObject:payload.data[key]];
            }
        }
    }

    [self.componentDisabler processDisableInfo:disableInfos];
    [self.modules processConfigs:configs];
}

@end
