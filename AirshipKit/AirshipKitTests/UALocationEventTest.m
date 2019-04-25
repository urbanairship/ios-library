/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UALocationEvent.h"

@interface UALocationEventTest : UABaseTest
@property (nonatomic, strong) UALocationInfo *locationInfo;
@end

@implementation UALocationEventTest

- (void)setUp {
    [super setUp];

    self.locationInfo = [UALocationInfo infoWithLatitude:45.525352839897 longitude:-122.682115697712 horizontalAccuracy:5.0 verticalAccuracy:5.0];
}

// Test creating a significant location update event
- (void)testSignificantLocationUpdate {
    UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithInfo:self.locationInfo
                                                                        providerType:@"testLocation"];

    [self validateLocationForEvent:event];

    XCTAssertEqualObjects(@"NONE", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"NONE", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqualObjects(@"CHANGE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqualObjects(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a single location update event
- (void)testSingleLocationUpdate {
    UALocationEvent *event = [UALocationEvent singleLocationEventWithInfo:self.locationInfo
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
    UALocationEvent *event = [UALocationEvent standardLocationEventWithInfo:self.locationInfo
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
    UALocationEvent *event = [UALocationEvent locationEventWithInfo:self.locationInfo
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
    XCTAssertEqualWithAccuracy(self.locationInfo.latitude, [[event.data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001);
    XCTAssertEqualWithAccuracy(self.locationInfo.longitude, [[event.data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001 );
    XCTAssertEqual((int)self.locationInfo.horizontalAccuracy, [[event.data valueForKey:UALocationEventHorizontalAccuracyKey] intValue]);
    XCTAssertEqual((int)self.locationInfo.verticalAccuracy, [[event.data valueForKey:UALocationEventVerticalAccuracyKey] intValue]);
}

@end
