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
#import "UARegionEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import <OCMock/OCMock.h>
#import "NSJSONSerialization+UAAdditions.h"
#import "UAProximityRegion+Internal.h"
#import "UACircularRegion+Internal.h"

@interface UARegionEventTest : XCTestCase
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@end

@implementation UARegionEventTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test region event data directly.
 */
- (void)testRegionEventData {
    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:@"region_id" source:@"source" boundaryEvent:UABoundaryEventEnter];
    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:@11 latitude:@45.5200 longitude:@122.6819];
    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:@"proximity_id" major:@1 minor:@11];

    proximityRegion.latitude = @45.5200;
    proximityRegion.longitude = @122.6819;
    proximityRegion.RSSI = @-59;

    event.circularRegion = circularRegion;
    event.proximityRegion = proximityRegion;

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
    XCTAssertEqualObjects(kUARegionBoundaryEventEnterValue, [event.data objectForKey:@"action"], @"Unexpected boundary event.");
}

/**
 * Test creating a region event and setting a valid circular region
 */
- (void)testSetCircularRegionEvent {
    NSString *regionID = [@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0];
    NSString *source = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];

    NSNumber *radius = @11;
    NSNumber *latitude = @45.5200;
    NSNumber *longitude = @122.6819;

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:regionID source:source boundaryEvent:UABoundaryEventExit];

    UACircularRegion *circularRegion = [UACircularRegion circularRegionWithRadius:radius latitude:latitude longitude:longitude];

    event.circularRegion = circularRegion;

    XCTAssertEqualObjects(regionID, [event.data objectForKey:@"region_id"], @"Unexpected region id.");
    XCTAssertEqualObjects(source, [event.data objectForKey:@"source"], @"Unexpected region source.");
    XCTAssertEqualObjects(kUARegionBoundaryEventExitValue, [event.data objectForKey:@"action"], @"Unexpected boundary event.");

    XCTAssertEqualObjects(@"11.0", [[event.data objectForKey:@"circular_region"] objectForKey:@"radius"], @"Unexpected radius.");
    XCTAssertEqualObjects(@"45.5200000", [[event.data objectForKey:@"circular_region"] objectForKey:@"latitude"], @"Unexpected latitude.");
    XCTAssertEqualObjects(@"122.6819000", [[event.data objectForKey:@"circular_region"] objectForKey:@"longitude"], @"Unexpected longitude.");
}

/**
 * Test creating a region event and setting a valid proximity region
 */
- (void)testSetProximityRegionEvent {
    NSString *regionID = [@"" stringByPaddingToLength:255 withString:@"REGION_ID" startingAtIndex:0];
    NSString *source = [@"" stringByPaddingToLength:255 withString:@"SOURCE" startingAtIndex:0];

    NSString *proximityID = [@"" stringByPaddingToLength:255 withString:@"PROXIMITY_ID" startingAtIndex:0];
    NSNumber *major = @1;
    NSNumber *minor = @2;

    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:regionID source:source boundaryEvent:UABoundaryEventExit];

    UAProximityRegion *proximityRegion = [UAProximityRegion proximityRegionWithID:proximityID major:major minor:minor];

    proximityRegion.latitude = @45.5200;
    proximityRegion.longitude = @122.6819;
    proximityRegion.RSSI = @-59;

    event.proximityRegion = proximityRegion;

    XCTAssertEqualObjects(event.proximityRegion.proximityID, [[event.data objectForKey:@"proximity"] objectForKey:@"proximity_id"], @"Unexpected proximity ID.");
    XCTAssertEqualObjects(event.proximityRegion.major, [[event.data objectForKey:@"proximity"] objectForKey:@"major"], @"Unexpected major.");
    XCTAssertEqualObjects(event.proximityRegion.minor, [[event.data objectForKey:@"proximity"] objectForKey:@"minor"], @"Unexpected minor.");
    XCTAssertEqualObjects(@"45.5200000", [[event.data objectForKey:@"proximity"] objectForKey:@"latitude"], @"Unexpected latitude.");
    XCTAssertEqualObjects(@"122.6819000", [[event.data objectForKey:@"proximity"] objectForKey:@"longitude"], @"Unexpected longitude.");
    XCTAssertEqualObjects(event.proximityRegion.RSSI, [[event.data objectForKey:@"proximity"] objectForKey:@"rssi"], @"Unexpected RSSI.");
}

/**
 * Test character count validation
 */
- (void)testCharacterCountValidation {
    NSString *validString = @"wat";
    NSString *invalidString = [@"" stringByPaddingToLength:256 withString:@"wat" startingAtIndex:0];

    XCTAssertTrue([UARegionEvent regionEventCharacterCountIsValid:validString], @"Region the string %@ should be valid.", validString);
    XCTAssertFalse([UARegionEvent regionEventCharacterCountIsValid:invalidString], @"Region event strings greater than 255 characters should be invalid.");
}

/**
 * Test latitude validation
 */
- (void)testLatitudeValidation {
    NSNumber *validLatitude = @11;
    NSNumber *invalidLatitudeMax = @(91);
    NSNumber *invalidLatitudeMin = @(-91);
    NSNumber *invalidLatitudeNil = nil;

    XCTAssertTrue([UARegionEvent regionEventLatitudeIsValid:validLatitude], @"The latitude %@ should be valid.", validLatitude);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLatitudeMax], @"The latitude %@ should be invalid.", invalidLatitudeMax);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLatitudeMin], @"The latitude %@ should be invalid.", invalidLatitudeMin);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLatitudeNil], @"Nil latitudes should be invalid.");
}

/**
 * Test longitude validation
 */
- (void)testLongitudeValidation {
    NSNumber *validLongitude = @11;
    NSNumber *invalidLongitudeMax = @(181);
    NSNumber *invalidLongitudeMin = @(-181);
    NSNumber *invalidLongitudeNil = nil;

    XCTAssertTrue([UARegionEvent regionEventLatitudeIsValid:validLongitude], @"The longitude %@ should be valid.", validLongitude);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLongitudeMax], @"The longitude %@ should be invalid.", invalidLongitudeMax);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLongitudeMin], @"The longitude %@ should be invalid.", invalidLongitudeMin);
    XCTAssertFalse([UARegionEvent regionEventLatitudeIsValid:invalidLongitudeNil], @"Nil longitudes should be invalid.");
}

/**
 * Test radius validation
 */
- (void)testRadiusValidation {
    NSNumber *validRadius = @11;
    NSNumber *invalidRadiusMax = @(100001);
    NSNumber *invalidRadiusMin = @(0);
    NSNumber *invalidRadiusNil = nil;

    XCTAssertTrue([UARegionEvent regionEventRadiusIsValid:validRadius], @"The radius %@ should be valid.", validRadius);
    XCTAssertFalse([UARegionEvent regionEventRadiusIsValid:invalidRadiusMax], @"The radius %@ should be invalid.", invalidRadiusMax);
    XCTAssertFalse([UARegionEvent regionEventRadiusIsValid:invalidRadiusMin], @"The radius %@ should be invalid.", invalidRadiusMin);
    XCTAssertFalse([UARegionEvent regionEventRadiusIsValid:invalidRadiusNil], @"Nil radii should be invalid.");
}

/**
 * Test RSSI validation
 */
- (void)testRSSIValidation {
    NSNumber *validRSSI = @11;
    NSNumber *invalidRSSIMax = @(101);
    NSNumber *invalidRSSIMin = @(-101);
    NSNumber *invalidRSSINil = nil;

    XCTAssertTrue([UARegionEvent regionEventRSSIIsValid:validRSSI], @"The RSSI %@ should be valid.", validRSSI);
    XCTAssertFalse([UARegionEvent regionEventRSSIIsValid:invalidRSSIMax], @"The RSSI %@ should be invalid.", invalidRSSIMax);
    XCTAssertFalse([UARegionEvent regionEventRSSIIsValid:invalidRSSIMin], @"The RSSI %@ should be invalid.", invalidRSSIMin);
    XCTAssertFalse([UARegionEvent regionEventRSSIIsValid:invalidRSSINil], @"Nil RSSIs should be invalid.");
}

/**
 * Test the event is high priority
 */
- (void)testHighPriority {
    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:@"id" source:@"source" boundaryEvent:UABoundaryEventEnter];
    XCTAssertEqual(UAEventPriorityHigh, event.priority);
}

@end
