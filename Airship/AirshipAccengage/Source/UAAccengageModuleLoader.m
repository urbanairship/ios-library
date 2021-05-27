/* Copyright Airship and Contributors */

#import "UAAccengageModuleLoader.h"
#import "UAAccengage+Internal.h"

@interface UAAccengageModuleLoader()
@property (nonatomic, strong) UAAccengage *accengage;
@end

@implementation UAAccengageModuleLoader

- (instancetype)initWithAccengage:(UAAccengage *)accengage{
    self = [super init];
    if (self) {
        self.accengage = accengage;
    }
    return self;
}

+ (id<UAModuleLoader>)moduleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                        channel:(UAChannel *)channel
                                           push:(UAPush *)push
                                 privacyManager:(UAPrivacyManager *)privacyManager {

    UAAccengage *accengage = [UAAccengage accengageWithDataStore:dataStore
                                                         channel:channel
                                                            push:push
                                                  privacyManager:privacyManager];

    return [[self alloc] initWithAccengage:accengage];
}

- (NSArray<UAComponent *> *)components {
    return @[self.accengage];
}

@end
