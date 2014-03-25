/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import <OCMock/OCMConstraint.h>

#import "UALocationService+Internal.h"
#import "UALocationEvent.h"
#import "UALocationCommonValues.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "UALocationTestUtils.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"

@interface UALocationEventApplicationTests : XCTestCase {
  @private
    CLLocation *_location;
}
@end

/**
 *  The context includes all the data necessary for a 
 *  location event. These are:
 *  
 *  "session_id": "UUID"
 *  "lat" : "31.3847" (required, DDD.dddd... string double)
 *  "long": "32.3847" (required, DDD.dddd... string double)
 *  "requested_accuracy": "10.0,100.0,NONE" (required, requested accuracy in meters as a string double)
 *  "update_type": "CHANGE, CONTINUOUS, SINGLE, NONE" (required - string enum)
 *  "provider": "GPS, NETWORK, PASSIVE, UNKNOWN" (required - string enum)
 *  "update_dist": "10.0,100.0,NONE" (required - string double distance in meters, or NONE if not available applicable)
 *  "h_accuracy": "10.0, NONE" (required, string double - actual horizontal accuracy in meters, or NONE if not available)
 *  "v_accuracy": "10.0, NONE" (required, string double - actual vertical accuracy in meters, or NONE if not available)
 *  "foreground": "true" (required, string boolean)
 */

@implementation UALocationEventApplicationTests

- (void)setUp {
    _location = [UALocationTestUtils testLocationPDX];
}

- (void)tearDown {

    _location = nil;

}

- (void)testInitWithLocationManager {
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:_location 
                                                        locationManager:locationManager 
                                                          andUpdateType:UALocationEventUpdateTypeSingle];
    NSDictionary *data = event.data;
    
    // 0.000001 equals sub meter accuracy at the equator. 
    XCTAssertEqualWithAccuracy(_location.coordinate.latitude, [[data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001);
    XCTAssertEqualWithAccuracy(_location.coordinate.longitude, [[data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001 );
    XCTAssertEqual((int)_location.horizontalAccuracy, [[data valueForKey:UALocationEventHorizontalAccuracyKey] intValue]);
    XCTAssertEqual((int)_location.verticalAccuracy, [[data valueForKey:UALocationEventVerticalAccuracyKey] intValue]);
    XCTAssertEqual((int)locationManager.desiredAccuracy, [[data valueForKey:UALocationEventDesiredAccuracyKey] intValue]);

    // update_type
    XCTAssertEqual((int )locationManager.distanceFilter, [[data valueForKey:UALocationEventDistanceFilterKey] intValue] );
    XCTAssertTrue((UALocationEventUpdateTypeSingle == [data valueForKey:UALocationEventUpdateTypeKey]) );
    XCTAssertEqualObjects(@"true" , [data valueForKey:UALocationEventForegroundKey]);
    XCTAssertTrue((UALocationServiceProviderUnknown == [data valueForKey:UALocationEventProviderKey]));
    XCTAssertEqualObjects([[UAirship shared].analytics.session valueForKey:@"session_id"], [event.data valueForKey:UALocationEventSessionIDKey], @"Session id should be set.");
}

- (void)testInitWithProvider {
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:_location provider:standard andUpdateType:UALocationEventUpdateTypeContinuous];
    NSDictionary *data = event.data;

    XCTAssertEqualWithAccuracy(_location.coordinate.latitude, [[data valueForKey:UALocationEventLatitudeKey] doubleValue], 0.000001);
    XCTAssertEqualWithAccuracy(_location.coordinate.longitude, [[data valueForKey:UALocationEventLongitudeKey] doubleValue],0.000001);
    XCTAssertEqual(_location.horizontalAccuracy, [[data valueForKey:UALocationEventHorizontalAccuracyKey] doubleValue]);
    XCTAssertEqual(_location.verticalAccuracy, [[data valueForKey:UALocationEventVerticalAccuracyKey] doubleValue]);
    XCTAssertEqual(standard.desiredAccuracy, [[data valueForKey:UALocationEventDesiredAccuracyKey] doubleValue]);
    XCTAssertEqual(standard.distanceFilter, [[data valueForKey:UALocationEventDistanceFilterKey] doubleValue] );
    XCTAssertTrue((UALocationEventUpdateTypeContinuous == [data valueForKey:UALocationEventUpdateTypeKey]) );
    XCTAssertEqualObjects(@"true" , [data valueForKey:UALocationEventForegroundKey]);
    XCTAssertTrue((UALocationServiceProviderGps == [data valueForKey:UALocationEventProviderKey]));
    XCTAssertEqualObjects([[UAirship shared].analytics.session valueForKey:@"session_id"], [event.data valueForKey:UALocationEventSessionIDKey], @"Session id should be set.");
}

- (void)testInitWithSigChangeProviderSetsDistanceFilterDesiredAccuracyNone {
    UASignificantChangeProvider *sigChange = [UASignificantChangeProvider providerWithDelegate:nil];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:_location provider:sigChange andUpdateType:UALocationEventUpdateTypeChange];
    XCTAssertTrue(UAAnalyticsValueNone == [event.data valueForKey:UALocationEventDesiredAccuracyKey], @"desiredAccuracy should be UADesiredAccuracyValueNone");
    XCTAssertTrue(UAAnalyticsValueNone == [event.data valueForKey:UALocationEventDistanceFilterKey], @"distanceFilter should be UADistanceFilterValueNone");
}

- (void)testInitWhenAnalyticsInBackground {
    [[UAirship shared].analytics enterBackground];
    
    UAStandardLocationProvider *standard = [UAStandardLocationProvider providerWithDelegate:nil];
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:_location provider:standard andUpdateType:UALocationEventUpdateTypeContinuous];

    XCTAssertEqualObjects(@"", [event.data valueForKey:UALocationEventSessionIDKey], @"Session id should be empty.");

    //Bring the analytics back into the foreground
    [[UAirship shared].analytics enterForeground];
}

@end
