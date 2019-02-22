/* Copyright Urban Airship and Contributors */

#import "UAComponentDisabler+Internal.h"
#import "UAVersionMatcher+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAComponent+Internal.h"
#import "UAApplicationMetrics.h"
#import "UAJSONPredicate.h"
#import "UAModules+Internal.h"

// Disable JSON keys
NSString * const UADisableModulesKey = @"modules";
NSString * const UADisableAllModules = @"all";
NSString * const UADisableRefreshIntervalKey = @"remote_data_refresh_interval";
NSString * const UADisableSDKVersionsKey = @"sdk_versions";
NSString * const UADisableAppVersionsKey = @"app_versions";

// Default values
NSUInteger const UADisableRefreshIntervalDefault = 0; // default is no minimum refresh interval

@interface UAComponentDisabler()
@property (nonatomic, strong) UAModules *modules;
@end

@implementation UAComponentDisabler

- (instancetype)initWithModules:(UAModules *)modules {
    self = [super init];

    if (self){
        self.modules = modules;
    }

    return self;
}

+ (instancetype)componentDisablerWithModules:(UAModules *)modules {
    return [[self alloc] initWithModules:modules];
}

- (void)processDisableInfo:(NSArray *)disableInfos {
    NSMutableSet<NSString *> *disableModuleIDs = [NSMutableSet set];
    NSUInteger remoteDataRefreshInterval = UADisableRefreshIntervalDefault;

    for (NSDictionary *disableInfo in disableInfos) {
        // If either SDK or App version constraint are provided but do not match, skip add
        if (disableInfo[UADisableSDKVersionsKey] && !([self disableInfo:disableInfo matchesSDKVersion:[UAirshipVersion get]])) {
            continue;
        }
        if (disableInfo[UADisableAppVersionsKey] && !([self disableInfo:disableInfo matchesAppVersion:[UAirship shared].applicationMetrics.currentAppVersion])) {
            continue;
        }

        // Modules
        if (disableInfo[UADisableModulesKey]) {
            id modules = disableInfo[UADisableModulesKey];

            if ([modules isKindOfClass:[NSString class]]) {
                if (![modules isEqualToString:UADisableAllModules]) {
                    UA_LERR("Invalid disable modules: %@", modules);
                    continue;
                }
                [disableModuleIDs addObjectsFromArray:[self.modules allModuleNames]];
            } else if ([modules isKindOfClass:[NSArray class]]) {
                [disableModuleIDs addObjectsFromArray:modules];
            } else {
                UA_LERR("Invalid disable modules: %@", modules);
                continue;
            }
        }

        // Remote data interval
        if (disableInfo[UADisableRefreshIntervalKey]) {
            NSUInteger interval = [disableInfo[UADisableRefreshIntervalKey] unsignedIntegerValue];
            remoteDataRefreshInterval = MAX(remoteDataRefreshInterval, interval);
        }
    }
    
    NSMutableSet<NSString *> *enableModuleIDs = [NSMutableSet setWithArray:[self.modules allModuleNames]];
    [enableModuleIDs minusSet:disableModuleIDs];

    // Disable modules
    for (NSString *moduleID in disableModuleIDs) {
        [self module:moduleID enable:NO];
    }

    // Enable modules
    for (NSString *moduleID in enableModuleIDs) {
        [self module:moduleID enable:YES];
    }

    // Update remote data refresh interval
    UAirship.remoteDataManager.remoteDataRefreshInterval = remoteDataRefreshInterval;
}

- (void)module:(NSString *)moduleID enable:(BOOL)enable {
    UAComponent *component = [self.modules airshipComponentForModuleName:moduleID];
    if ([component respondsToSelector:@selector(setComponentEnabled:)]) {
        [component setComponentEnabled:enable];
    } else {
        UA_LERR(@"Unable to enable/disable module: %@", moduleID);
    }
}

- (BOOL)disableInfo:(NSDictionary *)info matchesSDKVersion:(NSString *)version {
    if (![info[UADisableSDKVersionsKey] isKindOfClass:[NSArray class]]) {
        UA_LERR(@"Invalid sdk versions: %@", info[UADisableSDKVersionsKey]);
        return NO;
    }

    for (NSString *versionConstraint in info[UADisableSDKVersionsKey]) {
        UAVersionMatcher *versionMatcher = [UAVersionMatcher matcherWithVersionConstraint:versionConstraint];
        if ([versionMatcher evaluateObject:version]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)disableInfo:(NSDictionary *)info matchesAppVersion:(NSString *)version {
    if (![info[UADisableAppVersionsKey] isKindOfClass:[NSDictionary class]]) {
        UA_LERR(@"Invalid app versions: %@", info[UADisableAppVersionsKey]);
        return NO;
    }

    id versionPredicateJSON = info[UADisableAppVersionsKey];

    NSError *error = nil;
    UAJSONPredicate *versionPredicate = [UAJSONPredicate predicateWithJSON:versionPredicateJSON error:&error];

    if (error) {
        UA_LERR(@"Failed predicate JSON parsing with error: %@", error);
        return NO;
    }

    id versionObject = version ? @{@"ios" : @{@"version": version}} : nil;

    return versionObject && [versionPredicate evaluateObject:versionObject];
}

@end
