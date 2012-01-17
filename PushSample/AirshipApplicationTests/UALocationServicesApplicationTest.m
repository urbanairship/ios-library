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
    NSLog(@"lat %@", [eventData valueForKey:kLatKey]);
    STAssertNotNil(event, @"Event should not be nil");
    BOOL result = [self compareDoubleAsString:[eventData valueForKey:kLatKey] toDouble:kTestLat];
    STAssertTrue(result, @"kLatKey test lat should match result->%i kTestLat->%F eventLat->%@", result, kTestLat, [eventData valueForKey:kLatKey]);
    
}

- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue {
    double stringAsDouble = [stringDouble doubleValue];
    NSLog(@"stringValue %@", stringDouble);
    NSLog(@"stringAsDouble %F", stringAsDouble);
    return (stringAsDouble == doubleValue) ? YES:NO;
}
@end
