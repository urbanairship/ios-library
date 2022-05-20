/* Copyright Airship and Contributors */

#import "UALocation+Internal.h"

#if __has_include("AirshipBasement/AirshipBasement.h")
#import <AirshipBasement/AirshipBasement.h>
#else
#import "AirshipBasementLib.h"
#endif

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

NSString *const UALocationAutoRequestAuthorizationEnabled = @"UALocationAutoRequestAuthorizationEnabled";
NSString *const UALocationBackgroundUpdatesAllowed = @"UALocationBackgroundUpdatesAllowed";
NSString *const UALocationUpdatesEnabled = @"UALocationUpdatesEnabled";

@interface UALocation()
@property (nonatomic, strong) id<UAAnalyticsProtocol> analytics;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UAComponentDisableHelper *disableHelper;

@end

@interface UAPrivacyManager()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UALocation

+ (UALocation *)shared {
    return (UALocation *)[UAirship componentForClassName:NSStringFromClass([self class])];
}


- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(id<UAChannelProtocol>)channel
                        analytics:(id<UAAnalyticsProtocol>)analytics
                   privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super init];

    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.dataStore = dataStore;
        self.analytics = analytics;
        self.privacyManager = privacyManager;
        self.systemVersion = [[UASystemVersion alloc] init];
        self.locationManager.delegate = self;

        self.disableHelper = [[UAComponentDisableHelper alloc] initWithDataStore:dataStore
                                                                       className:@"UALocation"];

        UA_WEAKIFY(self)
        self.disableHelper.onChange = ^{
            UA_STRONGIFY(self);
            [self onComponentEnableChange];
        };
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        // Update the location service on app background
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UAAppStateTracker.didEnterBackgroundNotification
                                 object:nil];

        // Update the location service on app becoming active
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UAAppStateTracker.didBecomeActiveNotification
                                 object:nil];

        // Update the location service when enabled features change
        [notificationCenter addObserver:self
                               selector:@selector(onEnabledFeaturesChanged)
                                   name:UAPrivacyManager.changeEvent
                                 object:nil];

        if (self.componentEnabled) {
            [self updateLocationService];
        }

        [self.analytics addAnalyticsHeadersBlock:^NSDictionary<NSString *,NSString *> *{
            UA_STRONGIFY(self)
            return [self analyticsHeaders];
        }];

        [channel addRegistrationExtender:^(UAChannelRegistrationPayload *payload, void (^ completionHandler)(UAChannelRegistrationPayload * _Nonnull)) {
            UA_STRONGIFY(self)
            BOOL enabled = self.componentEnabled && self.locationUpdatesEnabled && [self.privacyManager isEnabled:UAFeaturesLocation];
            // Only set location settings if the app is opted in to data collection
            payload.channel.locationEnabledNumber = @(enabled);

            completionHandler(payload);
        }];
    }

    return self;
}

+ (instancetype)locationWithDataStore:(UAPreferenceDataStore *)dataStore
                              channel:(id<UAChannelProtocol>)channel
                            analytics:(id<UAAnalyticsProtocol>)analytics
                       privacyManager:(UAPrivacyManager *)privacyManager{
    return [[self alloc] initWithDataStore:dataStore channel:channel analytics:analytics privacyManager:privacyManager];
}

#pragma mark -
#pragma mark Analytics

- (NSDictionary<NSString *, NSString *> *)analyticsHeaders {
    if ([self.privacyManager isEnabled:UAFeaturesLocation] && self.componentEnabled) {
        return @{
            @"X-UA-Location-Permission": [self locationProviderPermissionStatus],
            @"X-UA-Location-Service-Enabled": self.locationUpdatesEnabled ? @"true" : @"false"
        };
    } else {
        return @{
            @"X-UA-Location-Service-Enabled": @"false"
        };
    }
}

- (NSString *)locationProviderPermissionStatus {
    if (![CLLocationManager locationServicesEnabled]) {
        return @"SYSTEM_LOCATION_DISABLED";
    } else {
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusDenied:
            case kCLAuthorizationStatusRestricted:
                return @"NOT_ALLOWED";
            case kCLAuthorizationStatusAuthorizedAlways:
                return @"ALWAYS_ALLOWED";
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                return @"FOREGROUND_ALLOWED";
            case kCLAuthorizationStatusNotDetermined:
                return @"UNPROMPTED";
        }
    }
}

- (BOOL)isAutoRequestAuthorizationEnabled {
    if (![self.dataStore objectForKey:UALocationAutoRequestAuthorizationEnabled]) {
        return YES;
    }

    return [self.dataStore boolForKey:UALocationAutoRequestAuthorizationEnabled];
}

- (void)setAutoRequestAuthorizationEnabled:(BOOL)autoRequestAuthorizationEnabled {
    [self.dataStore setBool:autoRequestAuthorizationEnabled forKey:UALocationAutoRequestAuthorizationEnabled];
}

- (BOOL)isLocationUpdatesEnabled {
    return [self.dataStore boolForKey:UALocationUpdatesEnabled];
}

- (void)setLocationUpdatesEnabled:(BOOL)locationUpdatesEnabled {
    if (locationUpdatesEnabled == self.isLocationUpdatesEnabled) {
        return;
    }

    [self.dataStore setBool:locationUpdatesEnabled forKey:UALocationUpdatesEnabled];
    [self updateLocationService];
}

- (BOOL)isComponentEnabled {
    return self.disableHelper.enabled;
}

- (void)setComponentEnabled:(BOOL)componentEnabled {
    self.disableHelper.enabled = componentEnabled;
}

- (BOOL)isBackgroundLocationUpdatesAllowed {
    return [self.dataStore boolForKey:UALocationBackgroundUpdatesAllowed];
}

- (void)setBackgroundLocationUpdatesAllowed:(BOOL)backgroundLocationUpdatesAllowed {
    if (backgroundLocationUpdatesAllowed == self.isBackgroundLocationUpdatesAllowed) {
        return;
    }

    [self.dataStore setBool:backgroundLocationUpdatesAllowed forKey:UALocationBackgroundUpdatesAllowed];

    if ([UAAppStateTracker shared].state != UAApplicationStateActive) {
        [self updateLocationService];
    }
}

- (CLLocation *)lastLocation {
    return self.locationManager.location;
}

- (void)updateLocationService {
    if (!self.componentEnabled || !self.locationUpdatesEnabled || ![self.privacyManager isEnabled:UAFeaturesLocation]) {
        [self stopLocationUpdates];
        return;
    }

#if !TARGET_OS_TV   // significantLocationChangeMonitoringAvailable not available on tvOS
    // Check if significant location updates are available
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        UA_LTRACE(@"Significant location updates unavailable.");
        [self stopLocationUpdates];
        return;
    }
#endif

    // Check if location updates are allowed in the background if we are in the background
    if ([UAAppStateTracker shared].state != UAApplicationStateActive && !self.isBackgroundLocationUpdatesAllowed) {
        [self stopLocationUpdates];
        return;
    }

    // Check authorization
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            UA_LTRACE(@"Authorization denied. Unable to start location updates.");
            [self stopLocationUpdates];
            break;

        case kCLAuthorizationStatusNotDetermined:
            [self requestAuthorization];
            break;

        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
        default:
            [self startLocationUpdates];
            break;
    }
}

- (void)stopLocationUpdates {
    if (!self.locationUpdatesStarted) {
        // Already stopped
        return;
    }

    UA_LINFO(@"Stopping location updates.");

#if !TARGET_OS_TV   // REVISIT - significant location updates not available on tvOS - should we use regular location updates?
    [self.locationManager stopMonitoringSignificantLocationChanges];
#endif
    self.locationUpdatesStarted = NO;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationUpdatesStopped)]) {
        [strongDelegate locationUpdatesStopped];
    }
}

- (void)startLocationUpdates {
    if (!self.componentEnabled || ![self.privacyManager isEnabled:UAFeaturesLocation]) {
        return;
    }

    if (self.locationUpdatesStarted) {
        // Already started
        return;
    }

    UA_LINFO(@"Starting location updates.");

#if !TARGET_OS_TV   // REVISIT - significant location updates not available on tvOS - should we use regular location updates?
    [self.locationManager startMonitoringSignificantLocationChanges];
#endif
    self.locationUpdatesStarted = YES;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationUpdatesStarted)]) {
        [strongDelegate locationUpdatesStarted];
    }
}

- (void)requestAuthorization NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    // Already requested
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined) {
        return;
    }

    if (!self.isAutoRequestAuthorizationEnabled) {
        UA_LINFO(@"Location updates require authorization, auto request authorization is disabled. You must manually request location authorization.");
        return;
    }

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        UA_LINFO(@"Location updates require authorization, but app is not active. Authorization will be requested next time the app is active.");
        return;
    }

    if (![self usageDescriptionsAreValid]) {
        return;
    }

    UA_LINFO(@"Requesting location authorization.");
#if TARGET_OS_TV //requestAlwaysAuthorization is not available on tvOS
    [self.locationManager requestWhenInUseAuthorization];
#else
    // This will potentially result in 'when in use' authorization
    [self.locationManager requestAlwaysAuthorization];
#endif
}

- (BOOL)usageDescriptionsAreValid {
#if TARGET_OS_TV
    // tvOS only needs the NSLocationWhenInUseUsageDescription to be valid
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
        UA_LERR(@"NSLocationWhenInUseUsageDescription not set, unable to request authorization.");
        return false;
    }
#else
    // iOS needs both the NSLocationWhenInUseUsageDescription && NSLocationAlwaysAndWhenInUseUsageDescription to be valid
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
        UA_LERR(@"NSLocationWhenInUseUsageDescription not set, unable to request always authorization.");
        return false;
    }
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"]) {
        UA_LERR(@"NSLocationAlwaysAndWhenInUseUsageDescription not set, unable to request always authorization.");
        return false;
    }
#endif

    return true;
}

- (BOOL)isLocationOptedIn {
    if (!self.locationUpdatesEnabled) {
        return NO;
    }

    if (![self.privacyManager isEnabled:UAFeaturesLocation]) {
        return NO;
    }

    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusNotDetermined:
            return NO;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return YES;
    }
}

- (BOOL)isLocationDeniedOrRestricted {
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            return YES;
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return NO;
    }
}

- (BOOL)isLocationAccuracyReduced {
    if (![self.privacyManager isEnabled:UAFeaturesLocation]) {
        return NO;
    }

    if (!self.locationUpdatesEnabled) {
        return NO;
    }

#if !TARGET_OS_MACCATALYST
    if (@available(iOS 14.0, *)) {
        switch (self.locationManager.accuracyAuthorization) {
            case CLAccuracyAuthorizationFullAccuracy:
                return NO;
            case CLAccuracyAuthorizationReducedAccuracy:
                return YES;
        }
    }
#endif

    return NO;
}

#pragma mark -
#pragma mark CLLocationManager Delegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UA_LTRACE(@"Location authorization changed: %d", status);

    [self updateLocationService];
}
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 14.0, *)) {
        UA_LTRACE(@"Location authorization changed: %d", manager.authorizationStatus);
    }

#endif
    [self updateLocationService];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    UA_LINFO(@"Received location updates: %@", locations);

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(receivedLocationUpdates:)]) {
        [strongDelegate receivedLocationUpdates:locations];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    UA_LTRACE(@"Location updates failed with error: %@", error);

    [self updateLocationService];
}

- (void)onComponentEnableChange {
    [self updateLocationService];
}

- (void)onEnabledFeaturesChanged {
    [self updateLocationService];
}

@end

