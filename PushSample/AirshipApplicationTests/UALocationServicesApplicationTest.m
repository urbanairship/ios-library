//
//  AirshipApplicationTests.m
//  AirshipApplicationTests
//
//  Created by Matt Hooge on 1/16/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServices.h"
#import "UALocationServicesCommon.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"

#define kTestLat 45.525352839897
#define kTestLong -122.682115697712
#define kTestAlt 100.0
#define kTestHorizontalAccuracy 5.0
#define kTestVerticalAccuracy 5.0
#define kTestDistanceFilter 10.0
#define kTestDesiredAccuracy 5.0

#import <SenTestingKit/SenTestingKit.h>

@interface UALocationServicesApplicationTest : SenTestCase
- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue;
@end


@implementation UALocationServicesApplicationTest

- (void)testCompareDoubleAsString {
    double five = 5.0;
    NSString *fiveString = @"5.0";
    NSString *six = @"6.0";
    BOOL goodResult = [self compareDoubleAsString:fiveString toDouble:five];
    BOOL badResult = [self compareDoubleAsString:six toDouble:five];
    STAssertEquals(YES, goodResult, @"good result should be good!");
    STAssertEquals(NO, badResult, @"bad result should be bad");
}
/**
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

- (void)testCreateEventWithLocationAndManager
{
    NSDate *dateNow = [NSDate date];
    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(kTestLat, kTestLong) altitude:kTestAlt horizontalAccuracy:kTestHorizontalAccuracy verticalAccuracy:kTestVerticalAccuracy timestamp:dateNow];
    UALocationManager *locationManager = [[UALocationManager alloc] initWithDelegateOrNil:nil];
    locationManager.desiredAccuracy = kTestDesiredAccuracy;
    locationManager.distanceFilter = kTestDistanceFilter;
    UAEvent *event = [UALocationServices createEventWithLocation:testLocation forManager:locationManager];
    NSLog(@"EVENT DATA %@", event.data);
    NSDictionary *eventData = event.data;
    NSComparisonResult compResult = [@"true" compare:[eventData valueForKey:kForegroundKey]];
    STAssertTrue((compResult == NSOrderedSame), @"kForegroundKey should be true");
    // The session test could be more robust TODO: add robustness!
    STAssertTrue(([[eventData valueForKey:kSessionIdKey] length] != 0), @"kSessionIdKey can't be empty");
    NSLog(@"lat %@", [eventData valueForKey:kLatKey]);
    STAssertNotNil(event, @"Event should not be nil");
    BOOL result = [self compareDoubleAsString:[eventData valueForKey:kLatKey] toDouble:kTestLat];
    STAssertTrue(result, @"kLatKey test lat should match  kTestLat->%F eventLat->%@", kTestLat, [eventData valueForKey:kLatKey]);
    result = [self compareDoubleAsString:[eventData valueForKey:kLongKey] toDouble:kTestLong];
    STAssertTrue(result, @"kLongKey test long should match i kLongKey->%F eventLong->%@", kTestLong, [eventData valueForKey:kLongKey]);
    result = [self compareDoubleAsString:[eventData valueForKey:kHorizontalAccuracyKey] toDouble:kTestHorizontalAccuracy];
    STAssertTrue(result, @"kHorzontalAccuracy  should match  kHorizontalAccuracy->%F evenHorizontalAccuracy->%@", kTestHorizontalAccuracy, [eventData valueForKey:kHorizontalAccuracyKey]);
    result = [self compareDoubleAsString:[eventData valueForKey:kVerticalAccuracyKey] toDouble:kTestVerticalAccuracy];
    STAssertTrue(result, @"kVerticalAccuracy should match kHorzontalAccuracy->%F eventHorizontalAccuracy->%@", kVerticalAccuracyKey, [eventData valueForKey:kVerticalAccuracyKey]);
    result = [self compareDoubleAsString:[eventData valueForKey:kUpdateDistanceKey] toDouble:kTestDistanceFilter];
    STAssertTrue(result, @"kUpdateDistance should match kTestDistanceFilter->%F eventDistanceFilter", kTestDistanceFilter, [eventData valueForKey:kUpdateDistanceKey]);
}

- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue {
    double stringAsDouble = [stringDouble doubleValue];
    NSLog(@"stringValue %@", stringDouble);
    NSLog(@"stringAsDouble %F", stringAsDouble);
    return (stringAsDouble == doubleValue) ? YES:NO;
}
@end
