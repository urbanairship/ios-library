/* Copyright Airship and Contributors */

#import "UAAutomationModuleLoader.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UAInAppAutomation+Internal.h"
#import "UAAutomationResources.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAAutomationModuleLoader()
@property (nonatomic, copy) NSArray<id<UAComponent>> *automationComponents;
@end

@implementation UAAutomationModuleLoader

- (instancetype)initWithComponents:(NSArray<id<UAComponent>> *)components {
    self = [super init];
    if (self) {
        self.automationComponents = components;
    }
    return self;
}

+ (id<UAModuleLoader>)inAppModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                              config:(UARuntimeConfig *)config
                                             channel:(UAChannel *)channel
                                             contact:(id<UAContactProtocol>)contact
                                           analytics:(UAAnalytics *)analytics
                                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                      privacyManager:(UAPrivacyManager *)privacyManager {

    NSMutableArray *components = [NSMutableArray array];

    UAInAppAudienceManager *audienceManager = [UAInAppAudienceManager managerWithConfig:config
                                                                              dataStore:dataStore
                                                                                channel:channel
                                                                              contact:contact];

    UAInAppAutomation *inAppAutomation = [UAInAppAutomation automationWithConfig:config
                                                                audienceManager:audienceManager
                                                              remoteDataProvider:remoteDataProvider
                                                                       dataStore:dataStore
                                                                         channel:channel
                                                                       analytics:analytics
                                                                  privacyManager:privacyManager];
    [components addObject:inAppAutomation];


    UALegacyInAppMessaging *legacyIAM = [UALegacyInAppMessaging inAppMessagingWithAnalytics:analytics
                                                                                  dataStore:dataStore
                                                                            inAppAutomation:inAppAutomation];
    [components addObject:legacyIAM];

    return [[self alloc] initWithComponents:components];
}

- (NSArray<id<UAComponent>> *)components {
    return self.automationComponents;
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSBundle *bundle = [UAAutomationResources bundle];
    NSString *path = [bundle pathForResource:@"UAAutomationActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}


@end


