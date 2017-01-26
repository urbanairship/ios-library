/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

#import "UALocation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAGlobal.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"

NSString *const UALocationAutoRequestAuthorizationEnabled = @"UALocationAutoRequestAuthorizationEnabled";
NSString *const UALocationUpdatesEnabled = @"UALocationUpdatesEnabled";
NSString *const UALocationBackgroundUpdatesAllowed = @"UALocationBackgroundUpdatesAllowed";

@implementation UALocation

- (instancetype)initWithAnalytics:(UAAnalytics *)analytics dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.dataStore = dataStore;
        self.analytics = analytics;

        // Update the location service on app background
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateLocationService)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        // Update the location service on app becoming active
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateLocationService)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        [self updateLocationService];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)locationWithAnalytics:(UAAnalytics *)analytics dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UALocation alloc] initWithAnalytics:analytics dataStore:dataStore];
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
    // Check if location updates are enabled
    if (!self.locationUpdatesEnabled) {
        [self stopLocationUpdates];
        return;
    }

    // Check if significant location updates are available
    if (![CLLocationManager significantLocationChangeMonitoringAvailable]) {
        UA_LTRACE("Significant location updates unavailable.");
        [self stopLocationUpdates];
        return;
    }

    // Check if location updates are allowed in the background if we are in the background
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && !self.isBackgroundLocationUpdatesAllowed) {
        [self stopLocationUpdates];
        return;
    }

    // Check authorization
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            UA_LTRACE("Authorizatoin denied. Unable to start location updates.");
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

    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.locationUpdatesStarted = NO;

    id strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationUpdatesStopped)]) {
        [strongDelegate locationUpdatesStopped];
    }
}

- (void)startLocationUpdates {
    if (self.locationUpdatesStarted) {
        // Already started
        return;
    }

    UA_LINFO("Starting location updates.");

    [self.locationManager startMonitoringSignificantLocationChanges];
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

    // Make sure the NSLocationAlwaysUsageDescription plist value is set
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"]) {
        UA_LERR(@"NSLocationAlwaysUsageDescription not set, unable to request authorization.");
        return;
    }

    UA_LINFO("Requesting location authorization.");
    [self.locationManager requestAlwaysAuthorization];
}


#pragma mark -
#pragma mark CLLocationManager Delegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UA_LTRACE(@"Location authorization changed: %d", status);

    [self updateLocationService];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
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

@end


