/* Copyright Urban Airship and Contributors */

#import "UAComponent+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

NSString * const UAComponentKey = @"UAComponent";
NSString * const UAComponentEnabledKey = @"enabled";
BOOL const UAComponentEnabledDefault = YES;

@interface UAComponent()

@property (nonatomic, strong) UAPreferenceDataStore *componentDataStore;

@end

@implementation UAComponent

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    
    if (self) {
        self.componentDataStore = dataStore;
    }
    
    return self;
}

- (NSString *)componentIdentifier {
    // default is to use the class name
    return NSStringFromClass([self class]);
}

// getter and setter for component enabled flag
- (BOOL)componentEnabled {
    // return value from the data store
    return [self.componentDataStore boolForKey:[self componentEnabledKey] defaultValue:UAComponentEnabledDefault];
}

- (void)setComponentEnabled:(BOOL)componentEnabled {
    BOOL valueChanged = (self.componentEnabled != componentEnabled);
    
    // save value to data store
    [self.componentDataStore setBool:componentEnabled forKey:[self componentEnabledKey]];
    
    if (valueChanged) {
        [self onComponentEnableChange];
    }
}

- (NSString *)componentEnabledKey {
    // compose key for data store
    return [NSString stringWithFormat:@"%@.%@.%@", UAComponentKey, [self componentIdentifier], UAComponentEnabledKey];
}

- (void)onComponentEnableChange {
    // placeholder - sub-classes should override if they want notification when the components enable/disable state changes
}

- (void)onNewRemoteConfig:(UARemoteConfig *)config  {
    // placeholder - sub-classes should override if they want remote config updates
}

- (nullable Class)remoteConfigClass {
    // placeholder - sub-classes should override if they want remote config updates
    return nil;
}

@end
