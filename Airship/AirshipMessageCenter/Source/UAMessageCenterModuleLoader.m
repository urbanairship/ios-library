/* Copyright Airship and Contributors */

#import "UAMessageCenterModuleLoader.h"
#import "UAMessageCenter+Internal.h"
#import "UAMessageCenterResources.h"

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
                                                     channel:(UAChannel<UAExtendableChannelRegistration> *)channel {

    UAMessageCenter *messageCenter = [UAMessageCenter messageCenterWithDataStore:dataStore
                                                                          config:config
                                                                         channel:channel];
    return [[self alloc] initWithMessageCenter:messageCenter];
}

- (NSArray<UAComponent *> *)components {
    return @[self.messageCenter];
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSString *path = [[UAMessageCenterResources bundle] pathForResource:@"UAMessageCenterActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}
@end
