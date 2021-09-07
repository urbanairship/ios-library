/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAEvent.h"

@import AirshipCore;

@interface UARegionEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UARegionEventTest

/**
 * Test region event data directly.
 */
- (void)testRegionEventData {
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:11
                                                                         latitude:45.5200
                                                                        longitude:122.6819];

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:@"proximity_id"
                                                                            major:1
                                                                            minor:11
                                                                             rssi:-59
                                                                         latitude:45.5200
                                                                        longitude:122.6819];

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:@"region_id"
                                                           source:@"source"
                                                    boundaryEvent:UABoundaryEventEnter
                                                   circularRegion:circularRegion
                                                  proximityRegion:proximityRegion];

    NSDictionary *expectedData = @{ @"action": @"enter",
                                    @"region_id": @"region_id",
                                    @"source": @"source",
                                    @"circular_region": @{
                                            @"latitude": @"45.5200000",
                                            @"longitude": @"122.6819000",
                                            @"radius": @"11.0"
                                            },
                                    @"proximity": @{ @"minor": @11,
                                                     @"rssi": @-59,
                                                     @"major": @1,
                                                     @"proximity_id": @"proximity_id",
                                                     @"latitude": @"45.5200000",
                                                     @"longitude": @"122.6819000"
                                                     }
                                    };

    XCTAssertEqualObjects(expectedData, event.data);
}

/**
 * Test setting a region event ID.
 */
- (void)testSetRegionEventID {
    NSString *regionID = [@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0];
    NSString *source = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:[@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0] source:source boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqualObjects(event.regionID, regionID, "255 character region ID should be valid");

    event = [UARegionEvent regionEventWithRegionID:[@"" stringByPaddingToLength:256 withString:@"REGION_ID" startingAtIndex:0] source:source boundaryEvent:UABoundaryEventEnter];
    XCTAssertNil(event, @"Region IDs larger than 255 characters should be ignored");

    event = [UARegionEvent regionEventWithRegionID:@"" source:source boundaryEvent:UABoundaryEventEnter];
    XCTAssertNil(event, @"Region IDs less than 1 character should be ignored");

    event = [UARegionEvent regionEventWithRegionID:[@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0] source:source boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqualObjects(event.regionID, regionID, "255 character region ID should be valid");
}

/**
 * Test setting a region event source.
 */
- (void)testSetSource {
    NSString *regionID = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];
    NSString *source = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:regionID source:source boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqualObjects(event.source, source, "255 character source should be valid");

    event = [UARegionEvent regionEventWithRegionID:regionID source:[@"" stringByPaddingToLength:256 withString:@"SOURCE" startingAtIndex:0] boundaryEvent:UABoundaryEventEnter];
    XCTAssertNil(event, @"Sources larger than 255 characters should be ignored");

    event = [UARegionEvent regionEventWithRegionID:regionID source:@"" boundaryEvent:UABoundaryEventEnter];
    XCTAssertNil(event, @"Sources less than 1 character should be ignored");

    event = [UARegionEvent regionEventWithRegionID:regionID source:[@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0] boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqualObjects(event.source, source, "255 character source should be valid");
}

/**
 * Test creating a region event without a proximity or circular region
 */
- (void)testRegionEvent {
    NSString *regionID = [@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0];
    NSString *source = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:regionID source:source boundaryEvent:UABoundaryEventEnter];

    XCTAssertEqualObjects(regionID, [event.data objectForKey:@"region_id"], @"Unexpected region id.");
    XCTAssertEqualObjects(source, [event.data objectForKey:@"source"], @"Unexpected region source.");
    XCTAssertEqualObjects(@"enter", [event.data objectForKey:@"action"], @"Unexpected boundary event.");
}

/**
 * Test the event is high priority
 */
- (void)testHighPriority {
    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:@"id" source:@"source" boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqual(UAEventPriorityHigh, event.priority);
}

@end
