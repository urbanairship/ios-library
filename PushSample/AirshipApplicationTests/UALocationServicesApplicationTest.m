//
//  AirshipApplicationTests.m
//  AirshipApplicationTests
//
//  Created by Matt Hooge on 1/16/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationUtils.h"
#import "UALocationServicesCommon.h"
#import "UALocationService.h"
#import "UALocationService_Private.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UALocationTestUtils.h"
#import <SenTestingKit/SenTestingKit.h>

@interface UALocationServicesApplicationTest : SenTestCase
- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue;
@end


@implementation UALocationServicesApplicationTest

#pragma mark -
#pragma mark Support Methods

- (void)testCompareDoubleAsString {
    double testValue = kTestLat;
    NSString *stringLat = @"45.525352839897";
    NSString *badStringLat = @"37.7726834626323";
    BOOL goodResult = [self compareDoubleAsString:stringLat toDouble:testValue];
    BOOL badResult = [self compareDoubleAsString:badStringLat toDouble:testValue];
    STAssertEquals(YES, goodResult, @"good result should be good!");
    STAssertEquals(NO, badResult, @"bad result should be bad");
}

- (BOOL)compareDoubleAsString:(NSString*)stringDouble toDouble:(double)doubleValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *numberFromString = [formatter numberFromString:stringDouble];
    NSNumber *numberFromDouble = [NSNumber numberWithDouble:doubleValue];
    NSLog(@"NUMBER FROM STRING %@", [numberFromString stringValue]);
    NSLog(@"NUBMER FORM DOUBLE %@", [numberFromDouble stringValue]);
    [formatter release];
    return [numberFromDouble isEqualToNumber:numberFromString];
}

//- (void) testStartStandardLocation {
//
//}
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



@end
