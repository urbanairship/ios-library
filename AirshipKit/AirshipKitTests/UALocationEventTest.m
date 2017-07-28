/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UALocationEvent.h"

@interface UALocationEventTest : UABaseTest
@property (nonatomic, strong) CLLocation *location;
@end

@implementation UALocationEventTest

- (void)setUp {
    [super setUp];

    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(45.525352839897, -122.682115697712);
    self.location = [[CLLocation alloc] initWithCoordinate:coord
                                                  altitude:100.0
                                        horizontalAccuracy:5.0
                                          verticalAccuracy:5.0
                                                 timestamp:[NSDate date]];
}

// Test creating a significant location update event
- (void)testSignificantLocationUpdate {
    UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithLocation:self.location
                                                                            providerType:@"testLocation"];

    [self validateLocationForEvent:event];

    XCTAssertEqualObjects(@"NONE", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"NONE", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqualObjects(@"CHANGE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqualObjects(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a single location update event
- (void)testSingleLocationUpdate {
    UALocationEvent *event = [UALocationEvent singleLocationEventWithLocation:self.location
                                                                 providerType:@"testLocation"
                                                              desiredAccuracy:@150
                                                               distanceFilter:@100];

    [self validateLocationForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqualObjects(@"SINGLE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqualObjects(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a standard location update event
- (void)testStandardLocationUpdate {
    UALocationEvent *event = [UALocationEvent standardLocationEventWithLocation:self.location
                                                                   providerType:@"testLocation"
                                                                desiredAccuracy:@150
                                                                 distanceFilter:@100];

    [self validateLocationForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqualObjects(@"CONTINUOUS", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqualObjects(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a location event without an update type
- (void)testLocationEventUpdate {
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:self.location
                                                                   providerType:@"testLocation"
                                                                desiredAccuracy:@150
                                                                 distanceFilter:@100];

    [self validateLocationForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqualObjects(@"NONE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqualObjects(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Helper method to validate the location data
- (void)validateLocationForEvent:(UALocationEvent *)event {
    // 0.000001 equals sub meter accuracy at the equator.
    XCTAssertEqualWithAccuracy(self.location.coordinate.latitude, [[event.data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001);
    XCTAssertEqualWithAccuracy(self.location.coordinate.longitude, [[event.data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001 );
    XCTAssertEqual((int)self.location.horizontalAccuracy, [[event.data valueForKey:UALocationEventHorizontalAccuracyKey] intValue]);
    XCTAssertEqual((int)self.location.verticalAccuracy, [[event.data valueForKey:UALocationEventVerticalAccuracyKey] intValue]);

}

@end
