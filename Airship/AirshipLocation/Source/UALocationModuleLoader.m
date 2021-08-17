/* Copyright Airship and Contributors */

#import "UALocationModuleLoader.h"
#import "UALocation+Internal.h"

@interface UALocationModuleLoader ()
@property (nonatomic, strong) UALocation *location;
@end

@implementation UALocationModuleLoader

- (instancetype)initWithLocation:(UALocation *)location {
    self = [super init];
    if (self) {
        self.location = location;
    }
    return self;
}

+ (nonnull id<UAModuleLoader>)locationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                                        channel:(id<UAChannelProtocol>)channel
                                                      analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics
                                                 privacyManager: (UAPrivacyManager *)privacyManager{

    UALocation *location = [UALocation locationWithDataStore:dataStore channel:channel analytics:analytics privacyManager:(UAPrivacyManager *)privacyManager];
    return [[self alloc] initWithLocation:location];
}

- (NSArray<UAComponent *> *)components {
    return @[self.location];
}

- (id<UALocationProvider>)locationProvider {
    return self.location;
}

@end
