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

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UALocation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAAnalytics.h"
#import "UALocationEvent.h"

@interface UALocationTest : XCTestCase

@property (nonatomic, strong) UALocation *location;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) id mockLocationManager;
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedBundle;

@end

@implementation UALocationTest

- (void)setUp {
    [super setUp];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UALocationTest."];

    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    self.mockAnalytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.mockLocationManager = [OCMockObject niceMockForClass:[CLLocationManager class]];

    self.location = [UALocation locationWithAnalytics:self.mockAnalytics dataStore:self.dataStore];
    self.location.locationManager = self.mockLocationManager;

    self.mockedBundle = [OCMockObject niceMockForClass:[NSBundle class]];
    [[[self.mockedBundle stub] andReturn:self.mockedBundle] mainBundle];
    [[[self.mockedBundle stub] andReturn:@"Always"] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"];
}

- (void)tearDown {
    [self.mockLocationManager stopMocking];
    [self.mockAnalytics stopMocking];
    [self.mockedApplication stopMocking];
    [self.mockedBundle stopMocking];

    [self.dataStore removeAll];

    [super tearDown];
}

/**
 * Test enabling location updates starts location updates when the application is active.
 */
- (void)testEnableLocationActiveStartsLocation {
    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we starting location updates
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates does not start location updates if the app is
 * inactive and backround location is not allowed.
 */
- (void)testEnableLocationInactive {
    // Make the app inactive
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Reject calls to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we starting location updates
    [self.mockLocationManager verify];
}


/**
 * Test enabling location updates starts location updates if the app is
 * inactive and backround location is allowed.
 */
- (void)testEnableLocationInactiveStartsLocation {
    // Make the app inactive
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Allow background location
    self.location.backgroundLocationUpdatesAllowed = YES;

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we starting location updates
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates does not start location updates if the app is
 * backgrounded and backround location is not allowed.
 */
- (void)testEnableLocationBackground {
    // Background the app
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Reject calls to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we starting location updates
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates starts location updates if the app is
 * backgrounded and backround location is allowed.
 */
- (void)testEnableLocationBackgroundStartsLocation {
    // Background the app
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Allow background location
    self.location.backgroundLocationUpdatesAllowed = YES;

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we starting location updates
    [self.mockLocationManager verify];
}

/**
 * Test disabling location updates stops location.
 */
- (void)testDisableLocationUpdates {
    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Expect to stop monitoring significant location changes
    [[self.mockLocationManager expect] stopMonitoringSignificantLocationChanges];

    // Disable location
    self.location.locationUpdatesEnabled = NO;

    // Verify we stopped location updates
    [self.mockLocationManager verify];
}

/**
 * Test allowing background updates starts location updates if location updates
 * are enabled and the app.
 */
- (void)testAllowBackgroundUpdates {
    // Background the app
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Allow background location
    self.location.backgroundLocationUpdatesAllowed = YES;

    // Verify we starting location services
    [self.mockLocationManager verify];
}

/**
 * Test disabling background updates stops location if the app is backgrounded.
 */
- (void)testDisallowBackgroundUpdates {
    // Background the app
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;
    self.location.backgroundLocationUpdatesAllowed = YES;

    // Expect to stop monitoring significant location changes
    [[self.mockLocationManager expect] stopMonitoringSignificantLocationChanges];

    // Disallow background location
    self.location.backgroundLocationUpdatesAllowed = NO;

    // Verify we stopped location updates
    [self.mockLocationManager verify];
}


/**
 * Test app becoming active starts location updates if enabled.
 */
- (void)testAppActive {
    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Make the app report that its active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Send the app did become active notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification
                                                        object:nil];

    // Verify we starting location services
    [self.mockLocationManager verify];
}

/**
 * Test app entering background stops location updates if background location is
 * not allowed.
 */
- (void)testAppEnterBackground {
    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Make the app report that its active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] stopMonitoringSignificantLocationChanges];

    // Send the app did become active notification
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification
                                                        object:nil];

    // Verify we starting location services
    [self.mockLocationManager verify];
}


/**
 * Test location updates generates a location event.
 */
- (void)testLocationEvent {

    CLLocation *testLocation = [UALocationTest createLocationWithLat:45.5231
                                                             lon:122.6765
                                                        accuracy:100.0
                                                             age:0];

    // Expect a location event
    [[self.mockAnalytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UALocationEvent class]]) {
            return NO;
        }

        UALocationEvent *event = obj;
        if (![[event.data valueForKey:UALocationEventProviderKey] isEqualToString:UALocationServiceProviderNetwork]) {
            return NO;
        }


        double lat = [[event.data valueForKey:UALocationEventLatitudeKey] doubleValue];
        if (fabs(lat - testLocation.coordinate.latitude) >= 0.000001) {
            return NO;
        }

        double lon = [[event.data valueForKey:UALocationEventLongitudeKey] doubleValue];
        if (fabs(lon - testLocation.coordinate.longitude) >= 0.000001) {
            return NO;
        }

        return YES;
    }]];

    // Notify location update
    [self.location locationManager:self.mockLocationManager didUpdateLocations:@[testLocation]];

    // Verify we generated a location event
    [self.mockAnalytics verify];

}

/**
 * Test location updates does not generate a location event if its older than
 * 300 seconds.
 */
- (void)testOldLocationEvent {
    // Reject any events
    [[self.mockAnalytics reject] addEvent:OCMOCK_ANY];

    // Create a test location older than 300 seconds
    CLLocation *testLocation = [UALocationTest createLocationWithLat:45.5231
                                                                 lon:122.6765
                                                            accuracy:100.0
                                                                 age:301.0];

    // Notify location update
    [self.location locationManager:self.mockLocationManager didUpdateLocations:@[testLocation]];

    // Verify we did not generate a location event
    [self.mockAnalytics verify];

}

/**
 * Test location updates does not generate a location event if the location is
 * invalid (accuracy < 0).
 */
- (void)testInvalidLocationEvent {
    // Reject any events
    [[self.mockAnalytics reject] addEvent:OCMOCK_ANY];

    // Create a test location with invalid accuracy
    CLLocation *testLocation = [UALocationTest createLocationWithLat:45.5231
                                                                 lon:122.6765
                                                            accuracy:-1
                                                                 age:0];

    // Notify location update
    [self.location locationManager:self.mockLocationManager didUpdateLocations:@[testLocation]];

    // Verify we did not generate a location event
    [self.mockAnalytics verify];
}


/**
 * Test enabling location updates when significant change is unavailable.
 */
- (void)testSignificantChangeUnavailable {
    // Reject any attempts to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location unavailable
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(NO)] significantLocationChangeMonitoringAvailable];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not start location updates
    [self.mockLocationManager verify];

}

/**
 * Test location updates do not start if the location authorization is denied.
 */
- (void)testAuthorizedDenied {
    // Reject any attempts to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Make location unathorized
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusDenied)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not start location updates
    [self.mockLocationManager verify];
}

/**
 * Test location updates do not start if the location authorization is restricted.
 */
- (void)testAuthorizedRestricted {
    // Reject any attempts to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Make location unathorized
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusRestricted)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not start location updates
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates requesting authorization when location updates
 * are requested.
 */
- (void)testRequestsAuthorization {
    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Expect authorization to be requested
    [[self.mockLocationManager expect] requestAlwaysAuthorization];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we requested location authorization
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates does not request authorization if auto request
 * authorization is disabled.
 */
- (void)testRequestsAuthorizationAutoRequestDisabled {
    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Reject auhorization to be requested
    [[self.mockLocationManager reject] requestAlwaysAuthorization];

    // Disbale auto authorization
    self.location.autoRequestAuthorizationEnabled = NO;

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not request location authorization
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates does not request authorization if the app
 * is currently inactive.
 */
- (void)testRequestsAuthorizationInactive {
    // Make the app inactive
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Reject auhorization to be requested
    [[self.mockLocationManager reject] requestAlwaysAuthorization];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not request location authorization
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates do not request authorization if the app
 * bundle does not contain a description for always on location use.
 */
- (void)testMissingAlwaysOnLocationDescription {
    // Stop mocking the bundle to remove the description
    [self.mockedBundle stopMocking];

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Reject auhorization to be requested
    [[self.mockLocationManager reject] requestAlwaysAuthorization];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not request location authorization
    [self.mockLocationManager verify];
}

/**
 * Helper method to generate a location
 */
+ (CLLocation *)createLocationWithLat:(double)lat lon:(double)lon accuracy:(double)accuracy age:(double)age {
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon)
                                  altitude:50.0
                        horizontalAccuracy:accuracy
                          verticalAccuracy:accuracy
                                 timestamp:[NSDate dateWithTimeIntervalSinceNow:age]];
}


@end
