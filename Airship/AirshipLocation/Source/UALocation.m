/* Copyright Airship and Contributors */

#import "UALocation+Internal.h"
#import "UALocationEvent.h"

NSString *const UALocationAutoRequestAuthorizationEnabled = @"UALocationAutoRequestAuthorizationEnabled";
NSString *const UALocationUpdatesEnabled = @"UALocationUpdatesEnabled";
NSString *const UALocationBackgroundUpdatesAllowed = @"UALocationBackgroundUpdatesAllowed";

@interface UALocation()
@property (nonatomic, strong) UAAnalytics<UAExtendableAnalyticsHeaders> *analytics;
@end

@implementation UALocation


- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                        analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.dataStore = dataStore;
        self.analytics = analytics;
        self.systemVersion = [UASystemVersion systemVersion];
        self.locationManager.delegate = self;

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        // Update the location service on app background
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UAApplicationDidEnterBackgroundNotification
                                 object:nil];

        // Update the location service on app becoming active
        [notificationCenter addObserver:self
                               selector:@selector(updateLocationService)
                                   name:UAApplicationDidBecomeActiveNotification
                                 object:nil];

        if (self.componentEnabled) {
            [self updateLocationService];
        }

        UA_WEAKIFY(self)
        [self.analytics addAnalyticsHeadersBlock:^NSDictionary<NSString *,NSString *> *{
            UA_STRONGIFY(self)
            return [self analyticsHeaders];
        }];

        [channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self)
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];
    }

    return self;
}

+ (instancetype)locationWithDataStore:(UAPreferenceDataStore *)dataStore
                              channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                            analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics {
    return [[self alloc] initWithDataStore:dataStore channel:channel analytics:analytics];
}

#pragma mark -
#pragma mark Channel Registration

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {

    // Only set location settings if the app is opted in to data collection
    if (self.isDataCollectionEnabled) {
        payload.locationSettings = self.locationUpdatesEnabled ? @(YES) : @(NO);
    }

    completionHandler(payload);
}

#pragma mark -
#pragma mark Analytics

- (NSDictionary<NSString *, NSString *> *)analyticsHeaders {
    return @{
        @"X-UA-Location-Permission": [self locationProviderPermissionStatus],
        @"X-UA-Location-Service-Enabled": self.locationUpdatesEnabled ? @"true" : @"false"
    };
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
    if (!self.componentEnabled) {
        [self stopLocationUpdates];
        return;
    }

    if (!self.isDataCollectionEnabled) {
        [self stopLocationUpdates];
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
    if ([UAAppStateTracker shared].state != UAApplicationStateActive && !self.isBackgroundLocationUpdatesAllowed) {
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
    if (!self.componentEnabled || !self.isDataCollectionEnabled) {
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
    if (!self.isDataCollectionEnabled) {
        return NO;
    }

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

- (BOOL)isLocationAccuracyReduced {
    if (!self.isDataCollectionEnabled) {
        return NO;
    }

    if (!self.locationUpdatesEnabled) {
        return NO;
    }
    
    if (@available(iOS 14.0, *)) {
        switch (self.locationManager.accuracyAuthorization) {
            case CLAccuracyAuthorizationFullAccuracy:
                return NO;
            case CLAccuracyAuthorizationReducedAccuracy:
                return YES;
        }
    }

    return NO;
}

#pragma mark -
#pragma mark CLLocationManager Delegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UA_LTRACE(@"Location authorization changed: %d", status);

    [self updateLocationService];
}
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (@available(iOS 14.0, *)) {
        UA_LTRACE(@"Location authorization changed: %d", manager.authorizationStatus);
    }
    
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

    UALocationInfo *info = [UALocationInfo infoWithLatitude:location.coordinate.latitude
                                                  longitude:location.coordinate.longitude
                                         horizontalAccuracy:location.horizontalAccuracy
                                           verticalAccuracy:location.verticalAccuracy];

    UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithInfo:info
                                                                        providerType:UALocationServiceProviderNetwork];

    [self.analytics addEvent:event];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    UA_LTRACE(@"Location updates failed with error: %@", error);

    [self updateLocationService];
}

- (void)onComponentEnableChange {
    [self updateLocationService];
}

- (void)onDataCollectionEnabledChanged {
    [self updateLocationService];
}

@end

