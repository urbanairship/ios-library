/* Copyright Airship and Contributors */

#import "UAMessageCenterSDKModule.h"
#import "UAMessageCenter+Internal.h"
#import "UAMessageCenterResources.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAMessageCenterSDKModule()
@property (nonatomic, strong) UAMessageCenter *messageCenter;
@end

@implementation UAMessageCenterSDKModule

- (instancetype)initWithMessageCenter:(UAMessageCenter *)messageCenter {
    self = [super init];
    if (self) {
        self.messageCenter = messageCenter;
    }
    return self;
}

- (NSArray<id<UAComponent>> *)components {
    return @[self.messageCenter];
}

+ (id<UASDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    UAPreferenceDataStore *dataStore = dependencies[UASDKDependencyKeys.dataStore];
    UARuntimeConfig *config = dependencies[UASDKDependencyKeys.config];
    UAChannel *channel = dependencies[UASDKDependencyKeys.channel];
    UAPrivacyManager *privacyManager = dependencies[UASDKDependencyKeys.privacyManager];
    
    UAMessageCenter *messageCenter = [UAMessageCenter messageCenterWithDataStore:dataStore
                                                                          config:config
                                                                         channel:channel
                                                                  privacyManager:privacyManager];
    return [[self alloc] initWithMessageCenter:messageCenter];
}

- (NSString *)actionsPlist {
    return [[UAMessageCenterResources bundle] pathForResource:@"UAMessageCenterActions" ofType:@"plist"];
}

@end
