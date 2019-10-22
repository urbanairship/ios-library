/* Copyright Airship and Contributors */

#import "UALocationModuleLoader.h"
#import "UALocation.h"

@interface UALocationModuleLoader ()
@property (nonatomic, strong) UALocation *location;
@end

@implementation UALocationModuleLoader

- (instancetype)initWithDatStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.location = [[UALocation alloc] initWithDataStore:dataStore];
    }
    return self;
}

+ (nonnull id<UAModuleLoader>)locationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[UALocationModuleLoader alloc] initWithDatStore:dataStore];
}

- (NSArray<UAComponent *> *)components {
    return @[self.location];
}

@end
