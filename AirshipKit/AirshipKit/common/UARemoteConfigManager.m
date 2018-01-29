/* Copyright 2018 Urban Airship and Contributors */

#import "UARemoteConfigManager+Internal.h"
#import "UADisposable.h"
#import "UAirship+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAComponentDisabler+Internal.h"

NSString * const UAAppConfigCommon = @"app_config";
NSString * const UAAppConfigIOS = @"app_config:ios";
NSString * const UARemoteConfigDisableKey = @"disable";

@interface UARemoteConfigManager()
@property (nonatomic, strong) UADisposable *remoteDataSubscription;
@property (nonatomic, strong) UAComponentDisabler *componentDisabler;
@end

@implementation UARemoteConfigManager

+ (UARemoteConfigManager *)remoteConfigManagerWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager componentDisabler:(UAComponentDisabler *)componentDisabler {
    return [[UARemoteConfigManager alloc] initWithRemoteDataManager:remoteDataManager componentDisabler:componentDisabler];
}

- (instancetype)initWithRemoteDataManager:(UARemoteDataManager *)remoteDataManager componentDisabler:(UAComponentDisabler *)componentDisabler {
    self = [super init];
    
    if (self) {
        self.componentDisabler = componentDisabler;
        self.remoteDataSubscription = [remoteDataManager subscribeWithTypes:@[UAAppConfigCommon, UAAppConfigIOS]
                                                                               block:^(NSArray<UARemoteDataPayload *> *remoteConfig) {
                                                                                   [self processRemoteConfig:remoteConfig];
                                                                               }];
    }
    
    return self;
}

- (void)dealloc {
    [self.remoteDataSubscription dispose];
}

- (void)processRemoteConfig:(NSArray<UARemoteDataPayload *> *)remoteConfig {
    NSMutableArray *disableInfos = [NSMutableArray array];
    for (UARemoteDataPayload *payload in remoteConfig) {
        if (payload.data[UARemoteConfigDisableKey]) {
            [disableInfos addObjectsFromArray:payload.data[UARemoteConfigDisableKey]];
        }
    }

    [self.componentDisabler processDisableInfo:disableInfos];
}


@end
