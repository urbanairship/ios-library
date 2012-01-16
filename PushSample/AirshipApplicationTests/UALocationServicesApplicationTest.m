//
//  AirshipApplicationTests.m
//  AirshipApplicationTests
//
//  Created by Matt Hooge on 1/16/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesApplicationTest.h"
#import "UALocationServices.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"


@implementation UALocationServicesApplicationTest


- (void)testCreateEventWithLocation
{
    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(45.0, 45.0) altitude:10.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    UAEvent *event = [UALocationServices createEventWithLocation:testLocation];
    STAssertNotNil(event, @"Event should not be nil");
    UAAnalytics* analytics = [UAirship shared].analytics;
    NSDictionary *dictionary = [analytics session];
    NSLog(@"DICTIONARY SESSION %@", dictionary);
}



@end
