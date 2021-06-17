/* Copyright Airship and Contributors */

#import "UARemoteConfigModuleAdapter+Internal.h"
#import "UAirship+Internal.h"
#import "UAComponent+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteConfigModuleNames+Internal.h"

NSString * const UAChannelClassName = @"UAChannel";
NSString * const UALocationClassName = @"UALocation";
NSString * const UALegacyInAppMessagingClassName = @"UALegacyInAppMessaging";
NSString * const UAInAppMessageManagerClassName = @"UAInAppMessageManager";
NSString * const UAActionAutomationClassName = @"UAActionAutomation";
NSString * const UAMessageCenterClassName = @"UAMessageCenter";
NSString * const UAirshipChatClassName = @"UAirshipChat";

@implementation UARemoteConfigModuleAdapter

- (NSArray *)componentsForModuleName:(NSString *)moduleName {
    if ([moduleName isEqualToString:kUARemoteConfigModulePush]) {
        return @[[UAirship push]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleChannel]) {
        return @[[UAirship channel]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleNamedUser]) {
           return @[[UAirship namedUser]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleContact]) {
        return @[[UAirship contact]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleAnalytics]) {
        return @[[UAirship analytics]];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleMessageCenter]) {
        id messageCenter = [[UAirship shared] componentForClassName:UAMessageCenterClassName];
        return messageCenter ? @[messageCenter] : @[];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleInAppMessaging]) {
        id IAM = [[UAirship shared] componentForClassName:UAInAppMessageManagerClassName];
        id legacyIAM = [[UAirship shared] componentForClassName:UALegacyInAppMessagingClassName];
        return IAM && legacyIAM ? @[IAM, legacyIAM] : @[];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleAutomation]) {
        id automation = [[UAirship shared] componentForClassName:UAActionAutomationClassName];
        return automation ? @[automation] : @[];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleLocation]) {
        id location = [[UAirship shared] componentForClassName:UALocationClassName];
        return location ? @[location] : @[];
    }

    if ([moduleName isEqualToString:kUARemoteConfigModuleChat]) {
        id chat = [[UAirship shared] componentForClassName:UAirshipChatClassName];
        return chat ? @[chat] : @[];
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
