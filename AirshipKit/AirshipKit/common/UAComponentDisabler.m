/* Copyright 2018 Urban Airship and Contributors */

#import "UAComponentDisabler+Internal.h"
#import "UAVersionMatcher+Internal.h"
#import "UAirshipVersion.h"
#import "UAirship+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAComponent+Internal.h"

// Disable JSON keys
NSString * const UADisableModulesKey = @"modules";
NSString * const UADisableAllModules = @"all";
NSString * const UADisableRefreshIntervalKey = @"remote_data_refresh_interval";
NSString * const UADisableSDKVersionsKey = @"sdk_versions";

// Modules
NSString * const UADisableModulesPush = @"push";
NSString * const UADisableModulesAnalytics = @"analytics";
NSString * const UADisableModulesMessageCenter = @"message_center";
NSString * const UADisableModulesInAppMessaging = @"in_app_v2";
NSString * const UADisableModulesAutomation = @"automation";
NSString * const UADisableModulesNamedUser = @"named_user";
NSString * const UADisableModulesLocation = @"location";

// Default values
NSUInteger const UADisableRefreshIntervalDefault = 0; // default is no minimum refresh interval

@interface UAComponentDisabler()
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *moduleMap;
@end

@implementation UAComponentDisabler

- (void)processDisableInfo:(NSArray *)disableInfos {
    NSMutableSet<NSString *> *disableModuleIDs = [NSMutableSet set];
    NSUInteger remoteDataRefreshInterval = UADisableRefreshIntervalDefault;

    for (NSDictionary *disableInfo in disableInfos) {
        // Matches SDK
        if (![self disableInfo:disableInfo matchesSDKVersion:[UAirshipVersion get]]) {
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
                [disableModuleIDs addObjectsFromArray:[self.moduleMap allKeys]];
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
    
    NSMutableSet<NSString *> *enableModuleIDs = [NSMutableSet setWithArray:[self.moduleMap allKeys]];
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

#pragma mark -
#pragma mark Properties and constants
- (NSDictionary<NSString *, NSString *> *)moduleMap {
    if (!_moduleMap) {
        _moduleMap = @{
          UADisableModulesPush:NSStringFromSelector(@selector(sharedPush)),
          UADisableModulesAnalytics:NSStringFromSelector(@selector(sharedAnalytics)),
          UADisableModulesAutomation:NSStringFromSelector(@selector(sharedAutomation)),
          UADisableModulesNamedUser:NSStringFromSelector(@selector(sharedNamedUser)),
          UADisableModulesLocation:NSStringFromSelector(@selector(sharedLocation)),
#if !TARGET_OS_TV
          UADisableModulesMessageCenter:NSStringFromSelector(@selector(sharedInbox)),
          UADisableModulesInAppMessaging:NSStringFromSelector(@selector(sharedInAppMessageManager)),
#endif
          };
    }
    return _moduleMap;
}


#pragma mark -
#pragma mark Utility functions
- (id)airshipComponentForIdentifier:(NSString *)identifier {
    NSString *uairshipProperty = self.moduleMap[identifier];
    if (uairshipProperty.length) {
        return [UAirship.shared valueForKey:uairshipProperty];
    } else {
        UA_LERR(@"No comonent with ID: %@", identifier);
        return nil;
    }
}

- (void)module:(NSString *)moduleID enable:(BOOL)enable {
    UAComponent *component = [self airshipComponentForIdentifier:moduleID];
    if ([component respondsToSelector:@selector(setComponentEnabled:)]) {
        [component setComponentEnabled:enable];
    } else {
        UA_LERR(@"Unable to enable/disable module: %@", moduleID);
    }
}

- (BOOL)disableInfo:(NSDictionary *)info matchesSDKVersion:(NSString *)version {
    if (!info[UADisableSDKVersionsKey]) {
        return YES;
    }

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

@end
