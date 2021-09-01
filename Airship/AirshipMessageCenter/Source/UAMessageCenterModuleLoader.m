/* Copyright Airship and Contributors */

#import "UAMessageCenterModuleLoader.h"
#import "UAMessageCenter+Internal.h"
#import "UAMessageCenterResources.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAMessageCenterModuleLoader()
@property (nonatomic, strong) UAMessageCenter *messageCenter;
@end

@implementation UAMessageCenterModuleLoader

- (instancetype)initWithMessageCenter:(UAMessageCenter *)messageCenter {
    self = [super init];
    if (self) {
        self.messageCenter = messageCenter;
    }
    return self;
}

+ (id<UAModuleLoader>)messageCenterModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                      config:(UARuntimeConfig *)config
                                                     channel:(UAChannel *)channel
                                              privacyManager:(UAPrivacyManager *)privacyManager {

    UAMessageCenter *messageCenter = [UAMessageCenter messageCenterWithDataStore:dataStore
                                                                          config:config
                                                                         channel:channel
                                                                  privacyManager:privacyManager];
    return [[self alloc] initWithMessageCenter:messageCenter];
}

- (NSArray<id<UAComponent>> *)components {
    return @[self.messageCenter];
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSString *path = [[UAMessageCenterResources bundle] pathForResource:@"UAMessageCenterActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}
@end
