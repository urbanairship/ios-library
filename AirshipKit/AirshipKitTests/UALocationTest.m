/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UALocation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAAnalytics.h"
#import "UALocationEvent.h"

@interface UALocationTest : UABaseTest

@property (nonatomic, strong) UALocation *location;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@property (nonatomic, strong) id mockAnalytics;
@property (nonatomic, strong) id mockLocationManager;
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedBundle;
@property (nonatomic, strong) id mockProcessInfo;
@property (nonatomic, assign) NSUInteger testOSMajorVersion;

@end

@implementation UALocationTest

- (void)setUp {
    [super setUp];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"ualocation.test.%@",self.name]];
    XCTAssertNotNil(self.dataStore);
    [self.dataStore removeAll]; // start with an empty datastore

    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];
    self.mockLocationManager = [self mockForClass:[CLLocationManager class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.location = [UALocation locationWithAnalytics:self.mockAnalytics dataStore:self.dataStore notificationCenter:self.notificationCenter];
    self.location.locationManager = self.mockLocationManager;
    self.location.componentEnabled = YES;

    self.mockedBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockedBundle stub] andReturn:self.mockedBundle] mainBundle];
    [[[self.mockedBundle stub] andReturn:@"Always"] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"];

    self.testOSMajorVersion = 10;
    self.mockProcessInfo = [self mockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];


}

- (void)tearDown {
    [self.mockLocationManager stopMocking];
    [self.mockAnalytics stopMocking];
    [self.mockedApplication stopMocking];
    [self.mockedBundle stopMocking];

    [self.dataStore removeAll];
    self.location = nil;

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
 * Test enabling location updates does not start location updates if location is disabled.
 */
- (void)testEnableLocationComponentDisabled {
    // Disable location component
    self.location.componentEnabled = NO;

    // Make the app inactive
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateInactive)] applicationState];

    // Authorize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Allow background location
    self.location.backgroundLocationUpdatesAllowed = YES;

    // Reject calls to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we start location updates
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
 * Test disabling location component stops location updates.
 */
- (void)testDisableLocationComponentStopsUpdates {
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

    // Disable location component
    self.location.componentEnabled = NO;

    // Verify we stopped location updates
    [self.mockLocationManager verify];
}

/**
 * Test enabling location component starts location updates.
 */
- (void)testEnableLocationComponentStartsUpdates {
    // Disable location component
    self.location.componentEnabled = NO;

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager expect] startMonitoringSignificantLocationChanges];

    // Enable location component
    self.location.componentEnabled = YES;

    // Verify we stopped location updates
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
 * Test allowing background updates doesn't start location updates if location updates
 * are enabled but the component is disabled.
 */
- (void)testAllowBackgroundUpdatesComponentDisabled {
    // Disable location component
    self.location.componentEnabled = NO;

    // Background the app
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateBackground)] applicationState];

    // Authroize location
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusAuthorizedAlways)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Enable location updates
    self.location.locationUpdatesEnabled = YES;

    // Expect to start monitoring significant location changes
    [[self.mockLocationManager reject] startMonitoringSignificantLocationChanges];

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
    [self.notificationCenter postNotificationName:UIApplicationDidBecomeActiveNotification
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
    [self.notificationCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
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
 * Test enabling location updates does request always authorization if the app
 * bundle contains a description for 'always and when and use' location description on iOS 11+.
 */
- (void)testAlwaysAndWhenInUseLocationDescription {
    // Stop mocking the bundle to remove the description
    [self.mockedBundle stopMocking];

    // Re-start mock to add the NSLocationAlwaysAndWhenInUseUsageDescription for iOS 11
    self.mockedBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockedBundle stub] andReturn:self.mockedBundle] mainBundle];
    [[[self.mockedBundle stub] andReturn:@"Always"] objectForInfoDictionaryKey:@"NSLocationAlwaysAndWhenInUseUsageDescription"];
    [[[self.mockedBundle stub] andReturn:@"When In Use"] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"];

    // Set mock iOS version to 11+
    self.testOSMajorVersion = 11;

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Expect auhorization to be requested
    [[self.mockLocationManager expect] requestAlwaysAuthorization];

    // Enable location
    self.location.locationUpdatesEnabled = YES;

    // Verify we did not request location authorization
    [self.mockLocationManager verify];
}

/**
 * Test enabling location updates do not request always authorization if the app
 * bundle does not contain a description for 'always and when and use' location description on iOS 11+.
 */
- (void)testMissingAlwaysAndWhenInUseLocationDescription {
    // Stop mocking the bundle to remove the description
    [self.mockedBundle stopMocking];

    // Set mock iOS version to 11+
    self.testOSMajorVersion = 11;

    // Make the app active
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    // Set the location authorization to be not determined
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(kCLAuthorizationStatusNotDetermined)] authorizationStatus];

    // Make significant location available
    [[[self.mockLocationManager stub] andReturnValue:OCMOCK_VALUE(YES)] significantLocationChangeMonitoringAvailable];

    // Expect auhorization to be requested
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

