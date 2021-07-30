/* Copyright Airship and Contributors */

#import "UAComponent+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString * const UAComponentKey = @"UAComponent";
NSString * const UAComponentEnabledKey = @"enabled";
BOOL const UAComponentEnabledDefault = YES;

@interface UAComponent()
@property (nonatomic, strong) UAPreferenceDataStore *componentDataStore;
@end

@implementation UAComponent

+ (null_unspecified instancetype)shared {
    return [[UAirship shared] componentForClassName:NSStringFromClass([self class])];
}

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

- (void)applyRemoteConfig:(nullable id)config  {
    // placeholder - sub-classes should override if they want remote config updates
}

- (void)airshipReady:(UAirship *)airship {
    // placeholder – subclasses should override if they need to know when the shared airship is ready.
}

- (BOOL)deepLink:(NSURL *)deepLink {
    return NO;
}

@end
