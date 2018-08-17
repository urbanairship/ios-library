/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const UAModulesPush;
extern NSString * const UAModulesAnalytics;
extern NSString * const UAModulesMessageCenter;
extern NSString * const UAModulesInAppMessaging;
extern NSString * const UAModulesAutomation;
extern NSString * const UAModulesNamedUser;
extern NSString * const UAModulesLocation;

@interface UAModules : NSObject

- (NSArray<NSString *> *)allModules;
- (nullable UAComponent *)airshipComponentForModule:(NSString *)module;
- (void)processConfigs:(NSDictionary *)configs;

@end

NS_ASSUME_NONNULL_END
