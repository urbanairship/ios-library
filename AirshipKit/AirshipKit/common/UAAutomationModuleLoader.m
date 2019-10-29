/* Copyright Airship and Contributors */

#import "UAAutomationModuleLoader.h"
#import "UAActionAutomation+Internal.h"

#if !TARGET_OS_TV   // IAM not supported
#import "UALegacyInAppMessaging+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#endif

@interface UAAutomationModuleLoader()
@property (nonatomic, copy) NSArray<UAComponent *> *automationComponents;
@end

@implementation UAAutomationModuleLoader

- (instancetype)initWithComponents:(NSArray<UAComponent *> *)components {
    self = [super init];
    if (self) {
        self.automationComponents = components;
    }
    return self;
}

+ (id<UAModuleLoader>)inAppModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                              config:(UARuntimeConfig *)config
                                             channel:(UAChannel *)channel
                                           analytics:(UAAnalytics *)analytics
                                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                    tagGroupsHistory:(id<UATagGroupsHistory>)tagGroupsHistory {

    NSMutableArray *components = [NSMutableArray array];
    UAActionAutomation *automation = [UAActionAutomation automationWithConfig:config dataStore:dataStore];
    [components addObject:automation];

#if !TARGET_OS_TV   // IAM not supported

    UAInAppMessageManager *IAM = [UAInAppMessageManager managerWithConfig:config
                                                         tagGroupsHistory:tagGroupsHistory
                                                       remoteDataProvider:remoteDataProvider
                                                                dataStore:dataStore
                                                                  channel:channel
                                                                analytics:analytics];
    [components addObject:IAM];


    UALegacyInAppMessaging *legacyIAM = [UALegacyInAppMessaging inAppMessagingWithAnalytics:analytics
                                                                                  dataStore:dataStore
                                                                        inAppMessageManager:IAM];
    [components addObject:legacyIAM];
#endif

    return [[self alloc] initWithComponents:components];
}

- (NSArray<UAComponent *> *)components {
    return self.automationComponents;
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSString *path = [[UAirship resources] pathForResource:@"UAAutomationActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}


@end
