/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UALocation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAGlobal.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"
#import "UASystemVersion+Internal.h"


NSString *const UALocationAutoRequestAuthorizationEnabled = @"UALocationAutoRequestAuthorizationEnabled";
NSString *const UALocationUpdatesEnabled = @"UALocationUpdatesEnabled";
NSString *const UALocationBackgroundUpdatesAllowed = @"UALocationBackgroundUpdatesAllowed";

@implementation UALocation

- (instancetype)initWithAnalytics:(UAAnalytics *)analytics dataStore:(UAPreferenceDataStore *)dataStore notificationCenter:(NSNotificationCenter *)notificationCenter systemVersion:(UASystemVersion *)systemVersion {
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.dataStore = dataStore;
        self.analytics = analytics;
        self.systemVersion = systemVersion;

        // Update the location service on app background
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];

        // Update the location service on app becoming active
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UIApplicationDidBecomeActiveNotification
                                 object:nil];

        if (self.componentEnabled) {
            [self updateLocationService];
        }
    }

    return self;
}


+ (instancetype)locationWithAnalytics:(UAAnalytics *)analytics
                            dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UALocation alloc] initWithAnalytics:analytics
                                       dataStore:dataStore
                              notificationCenter:[NSNotificationCenter defaultCenter]
                                   systemVersion:[UASystemVersion systemVersion]];
}

+ (instancetype)locationWithAnalytics:(UAAnalytics *)analytics
                            dataStore:(UAPreferenceDataStore *)dataStore
                   notificationCenter:(NSNotificationCenter *)notificationCenter
                        systemVersion:(UASystemVersion *)systemVersion {
    return [[UALocation alloc] initWithAnalytics:analytics
                                       dataStore:dataStore
                              notificationCenter:notificationCenter
                                   systemVersion:systemVersion];
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

- (BOOL)isBackgroundLocationUpdatesAllowed {
    return [self.dataStore boolForKey:UALocationBackgroundUpdatesAllowed];
}

- (void)setBackgroundLocationUpdatesAllowed:(BOOL)backgroundLocationUpdatesAllowed {
    if (backgroundLocationUpdatesAllowed == self.isBackgroundLocationUpdatesAllowed) {
        return;
    }

    [self.dataStore setBool:backgroundLocationUpdatesAllowed forKey:UALocationBackgroundUpdatesAllowed];

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        [self updateLocationService];
    }
}

- (CLLocation *)lastLocation {
    return self.locationManager.location;
}

- (void)updateLocationService {
    if (!self.componentEnabled) {
        return;
    }
    
    // Check if location updates are enabled
    if (!self.locationUpdatesEnabled) {
        [self stopLocationUpdates];
        return;
    }

#if !TARGET_OS_TV   // significantLocationChangeMonitoringAvailable not available on tvOS
    // Check if significant location updates are available
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        UA_LTRACE("Significant location updates unavailable.");
        [self stopLocationUpdates];
        return;
    }
#endif

    // Check if location updates are allowed in the background if we are in the background
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && !self.isBackgroundLocationUpdatesAllowed) {
        [self stopLocationUpdates];
        return;
    }

    // Check authorization
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            UA_LTRACE("Authorization denied. Unable to start location updates.");
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

    UA_LINFO("Stopping location updates.");

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
    if (!self.componentEnabled) {
        return;
    }
    
    if (self.locationUpdatesStarted) {
        // Already started
        return;
    }

    UA_LINFO("Starting location updates.");

#if !TARGET_OS_TV   // REVISIT - significant location updates not available on tvOS - should we use regular location updates?
    [self.locationManager startMonitoringSignificantLocationChanges];
#endif
    self.locationUpdatesStarted = YES;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationUpdatesStarted)]) {
        [strongDelegate locationUpdatesStarted];
    }
}

- (void)requestAuthorization {
    // Already requested
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined) {
        return;
    }

    if (!self.isAutoRequestAuthorizationEnabled) {
        UA_LINFO("Location updates require authorization, auto request authorization is disabled. You must manually request location authorization.");
        return;
    }

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        UA_LINFO("Location updates require authorization, but app is not active. Authorization will be requested next time the app is active.");
        return;
    }

    if (![self usageDescriptionsAreValid]) {
        return;
    }

    UA_LINFO("Requesting location authorization.");
#if TARGET_OS_TV //requestAlwaysAuthorization is not available on tvOS
    [self.locationManager requestWhenInUseAuthorization];
#else
    // On iOS 11+ this will potentially result in 'when in use' authorization
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
    if ([self.systemVersion isGreaterOrEqualToVersion:@"11.0.0"]) {
        // iOS >11 needs both the NSLocationWhenInUseUsageDescription && NSLocationAlwaysAndWhenInUseUsageDescription to be valid
        if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
            UA_LERR(@"NSLocationWhenInUseUsageDescription not set, unable to request always authorization.");
            return false;
        }
        if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"]) {
            UA_LERR(@"NSLocationAlwaysAndWhenInUseUsageDescription not set, unable to request always authorization.");
            return false;
        }
    } else {
        // iOS <11 only needs the NSLocationAlwaysUsageDescription to be valid
        if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"]) {
            UA_LERR(@"NSLocationAlwaysUsageDescription not set, unable to request authorization.");
            return false;
        }
    }
#endif

    return true;
}

- (BOOL)isLocationOptedIn {
    if (!self.locationUpdatesEnabled) {
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

- (NSString *)locationPermissionDescription {
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



#pragma mark -
#pragma mark CLLocationManager Delegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UA_LTRACE(@"Location authorization changed: %d", status);

    [self updateLocationService];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    UA_LINFO(@"Received location updates: %@", locations);

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(receivedLocationUpdates:)]) {
        [strongDelegate receivedLocationUpdates:locations];
    }

    CLLocation *location = [locations lastObject];

    // Throw out old values
    if ([location.timestamp timeIntervalSinceNow] > 300.0) {
        return;
    }

    // Throw out locations with accuracy values less than zero that represent invalid lat/long values
    if (location.horizontalAccuracy < 0) {
        UA_LTRACE(@"Location %@ did not meet accuracy requirements", location);
        return;
    }

    UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithLocation:location
                                                                            providerType:UALocationServiceProviderNetwork];
    [self.analytics addEvent:event];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    UA_LTRACE(@"Location updates failed with error: %@", error);

    [self updateLocationService];
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, start updating the location
        [self updateLocationService];
    } else {
        // if component was enabled and is now disabled, stop updating the location
        [self stopLocationUpdates];
    }
}

@end


