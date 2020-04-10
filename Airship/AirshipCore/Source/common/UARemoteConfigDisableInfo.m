/* Copyright Airship and Contributors */

#import "UAGlobal.h"
#import "UARemoteConfigDisableInfo+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"

// Disable JSON keys
NSString * const UARemoteConfigDisableModulesKey = @"modules";
NSString * const UARemoteConfigDisableAllModules = @"all";
NSString * const UARemoteConfigDisableRefreshIntervalKey = @"remote_data_refresh_interval";
NSString * const UARemoteConfigDisableSDKVersionsKey = @"sdk_versions";
NSString * const UARemoteConfigDisableAppVersionsKey = @"app_versions";

// Default values
NSUInteger const UARemoteConfigDisableRefreshIntervalDefault = 0; // default is no minimum refresh interval

@interface UARemoteConfigDisableInfo()
@property (nonatomic, copy) NSArray<NSString *> *disableModuleNames;
@property (nonatomic, strong) UAJSONPredicate *appVersionConstraint;
@property (nonatomic, copy) NSArray<UAVersionMatcher *> *sdkVersionConstraints;
@property (nonatomic, strong) NSNumber *remoteDataRefreshInterval;
@end

@implementation UARemoteConfigDisableInfo

- (instancetype)initWithModuleNames:(NSArray<NSString *> *)disableModuleNames
              sdkVersionConstraints:(NSArray<UAVersionMatcher *> *)sdkVersionConstraints
               appVersionConstraint:(UAJSONPredicate *)appVersionConstraint
          remoteDataRefreshInterval:(NSNumber *)remoteDataRefreshInterval {
    self = [super init];
    if (self) {
        self.disableModuleNames = disableModuleNames;
        self.sdkVersionConstraints = sdkVersionConstraints;
        self.appVersionConstraint = appVersionConstraint;
        self.remoteDataRefreshInterval = remoteDataRefreshInterval;
    }
    return self;
}

+ (instancetype)disableInfoWithModuleNames:(NSArray<NSString *> *)disableModuleNames
                     sdkVersionConstraints:(NSArray<UAVersionMatcher *> *)sdkVersionConstraints
                      appVersionConstraint:(nullable UAJSONPredicate *)appVersionConstraint
                 remoteDataRefreshInterval:(nullable NSNumber *)remoteDataRefreshInterval {

    return [[self alloc] initWithModuleNames:disableModuleNames
                       sdkVersionConstraints:sdkVersionConstraints
                        appVersionConstraint:appVersionConstraint
                   remoteDataRefreshInterval:remoteDataRefreshInterval];
}

+ (instancetype)disableInfoWithJSON:(id)JSON {
    if (![JSON isKindOfClass:[NSDictionary class]]) {
        UA_LERR("Invalid disable info: %@", JSON);
        return nil;
    }

    NSMutableArray<NSString *> *moduleNames = [NSMutableArray array];
    NSMutableArray<UAVersionMatcher *> *sdkVersionConstraints = [NSMutableArray array];
    UAJSONPredicate *appVersionConstraint;
    NSNumber *remoteDataRefreshInterval;

    // Modules
    if (JSON[UARemoteConfigDisableModulesKey]) {
        id modules = JSON[UARemoteConfigDisableModulesKey];

        if ([modules isKindOfClass:[NSString class]]) {
            if (![modules isEqualToString:UARemoteConfigDisableAllModules]) {
                UA_LERR("Invalid disable modules: %@", modules);
                return nil;
            } else {
                [moduleNames addObjectsFromArray:kUARemoteConfigModuleAllModules];
            }
        } else if ([modules isKindOfClass:[NSArray class]]) {
            [moduleNames addObjectsFromArray:modules];
        } else {
            UA_LERR("Invalid disable modules: %@", modules);
            return nil;
        }
    }

    // App version constraint predicate
    if (JSON[UARemoteConfigDisableAppVersionsKey]) {
        if (![JSON[UARemoteConfigDisableAppVersionsKey] isKindOfClass:[NSDictionary class]]) {
            UA_LERR(@"Invalid app versions: %@", JSON[UARemoteConfigDisableAppVersionsKey]);
            return nil;
        }

        NSError *error = nil;
        appVersionConstraint = [UAJSONPredicate predicateWithJSON:JSON[UARemoteConfigDisableAppVersionsKey] error:&error];
        if (error) {
            UA_LERR(@"Failed predicate JSON parsing with error: %@", error);
            return nil;
        }
    }

    // SDK version constraint predicate
    if (JSON[UARemoteConfigDisableSDKVersionsKey]) {
        if (![JSON[UARemoteConfigDisableSDKVersionsKey] isKindOfClass:[NSArray class]]) {
            UA_LERR(@"Invalid sdk constraints: %@", JSON[UARemoteConfigDisableSDKVersionsKey]);
            return nil;
        }

        for (id versionConstraint in JSON[UARemoteConfigDisableSDKVersionsKey]) {
            if (![versionConstraint isKindOfClass:[NSString class]]) {
                UA_LERR(@"Invalid sdk constraint: %@", versionConstraint);
                return nil;
            }

            UAVersionMatcher *versionMatcher = [UAVersionMatcher matcherWithVersionConstraint:versionConstraint];
            if (!versionMatcher) {
                UA_LERR(@"Invalid sdk constraint: %@", versionConstraint);
                return nil;
            }
            [sdkVersionConstraints addObject:versionMatcher];
        }
    }

     // Remote data interval
    if (JSON[UARemoteConfigDisableRefreshIntervalKey]) {
        if (![JSON[UARemoteConfigDisableRefreshIntervalKey] isKindOfClass:[NSNumber class]]) {
            UA_LERR(@"Invalid remote config refresh interval: %@", JSON[UARemoteConfigDisableRefreshIntervalKey]);
            return nil;
        }
        remoteDataRefreshInterval = JSON[UARemoteConfigDisableRefreshIntervalKey];
    }

    return [self disableInfoWithModuleNames:moduleNames
                      sdkVersionConstraints:sdkVersionConstraints
                       appVersionConstraint:appVersionConstraint
                  remoteDataRefreshInterval:remoteDataRefreshInterval];
}

@end
