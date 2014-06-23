//
//  UALocationEventTest.m
//  AirshipLib
//
//  Created by Ryan Lepinski on 6/23/14.
//
//

#import <XCTest/XCTest.h>
#import "UALocationEvent.h"
#import "UALocationTestUtils.h"

@interface UALocationEventTest : XCTestCase
@property (nonatomic, strong) CLLocation *location;
@end

@implementation UALocationEventTest

- (void)setUp {
    [super setUp];
    self.location = [UALocationTestUtils testLocationPDX];
}

// Test creating a significant locatino update event
- (void)testSignificantLocationUpdate {
    UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithLocation:self.location
                                                                            providerType:@"testLocation"];

    [self validateLocaitonForEvent:event];

    XCTAssertEqual(@"NONE", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqual(@"NONE", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqual(@"CHANGE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqual(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a single location update event
- (void)testSingleLocationUpdate {
    UALocationEvent *event = [UALocationEvent singleLocationEventWithLocation:self.location
                                                                 providerType:@"testLocation"
                                                              desiredAccuracy:@150
                                                               distanceFilter:@100];

    [self validateLocaitonForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqual(@"SINGLE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqual(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a standard location update event
- (void)testStandardLocationUpdate {
    UALocationEvent *event = [UALocationEvent standardLocationEventWithLocation:self.location
                                                                   providerType:@"testLocation"
                                                                desiredAccuracy:@150
                                                                 distanceFilter:@100];

    [self validateLocaitonForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqual(@"CONTINUOUS", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqual(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Test creating a location event without an update type
- (void)testLocationEventUpdate {
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:self.location
                                                                   providerType:@"testLocation"
                                                                desiredAccuracy:@150
                                                                 distanceFilter:@100];

    [self validateLocaitonForEvent:event];

    XCTAssertEqualObjects(@"150", [event.data valueForKey:UALocationEventDesiredAccuracyKey]);
    XCTAssertEqualObjects(@"100", [event.data valueForKey:UALocationEventDistanceFilterKey]);
    XCTAssertEqual(@"NONE", [event.data valueForKey:UALocationEventUpdateTypeKey]);
    XCTAssertEqual(@"testLocation", [event.data valueForKey:UALocationEventProviderKey]);
}

// Helper mehtod to validate the location data
- (void)validateLocaitonForEvent:(UALocationEvent *)event {
    // 0.000001 equals sub meter accuracy at the equator.
    XCTAssertEqualWithAccuracy(self.location.coordinate.latitude, [[event.data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001);
    XCTAssertEqualWithAccuracy(self.location.coordinate.longitude, [[event.data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001 );
    XCTAssertEqual((int)self.location.horizontalAccuracy, [[event.data valueForKey:UALocationEventHorizontalAccuracyKey] intValue]);
    XCTAssertEqual((int)self.location.verticalAccuracy, [[event.data valueForKey:UALocationEventVerticalAccuracyKey] intValue]);

}

@end
