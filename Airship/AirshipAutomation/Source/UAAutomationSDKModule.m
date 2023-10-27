/* Copyright Airship and Contributors */

#import "UAAutomationSDKModule.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UAInAppAutomation+Internal.h"
#import "UAAutomationResources.h"
#import "UALandingPageAction.h"
#import "UACancelSchedulesAction.h"
#import "UAScheduleAction.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAAutomationSDKModule()
@property (nonatomic, copy) NSArray<id<UAComponent>> *automationComponents;
@end

@implementation UAAutomationSDKModule

- (instancetype)initWithComponents:(NSArray<id<UAComponent>> *)components {
    self = [super init];
    if (self) {
        self.automationComponents = components;
    }
    return self;
}

- (NSArray<id<UAComponent>> *)components {
    return self.automationComponents;
}

- (NSArray<id<UALegacyAction>> *)actions {
    return @[
        [[UALandingPageAction alloc] init],
        [[UACancelSchedulesAction alloc] init],
        [[UAScheduleAction alloc] init],
    ];
}

+ (id<UALegacySDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    UAPreferenceDataStore *dataStore = dependencies[UASDKDependencyKeys.dataStore];
    UARuntimeConfig *config = dependencies[UASDKDependencyKeys.config];
    UAChannel *channel = dependencies[UASDKDependencyKeys.channel];
    UAInAppCoreSwiftBridge *inAppCoreSwiftBridge = dependencies[UASDKDependencyKeys.inAppCoreSwiftBridge];
    UAAnalytics *analytics = dependencies[UASDKDependencyKeys.analytics];
    UAPrivacyManager *privacyManager = dependencies[UASDKDependencyKeys.privacyManager];
    
    
    UAInAppAutomation *inAppAutomation = [UAInAppAutomation automationWithConfig:config
                                                            inAppCoreSwiftBridge:inAppCoreSwiftBridge
                                                                       dataStore:dataStore
                                                                         channel:channel
                                                                       analytics:analytics
                                                                  privacyManager:privacyManager];

    UALegacyInAppMessaging *legacyIAM = [UALegacyInAppMessaging inAppMessagingWithAnalytics:analytics
                                                                                  dataStore:dataStore
                                                                            inAppAutomation:inAppAutomation];
    return [[self alloc] initWithComponents:@[inAppAutomation, legacyIAM]];
}

- (NSString *)actionsPlist {
    return [[UAAutomationResources bundle] pathForResource:@"UAAutomationActions" ofType:@"plist"];
}

@end


