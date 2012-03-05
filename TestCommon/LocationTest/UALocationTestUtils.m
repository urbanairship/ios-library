//
//  UALocationTestUtils.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/20/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationTestUtils.h"

@implementation UALocationTestUtils

+ (CLLocation*)testLocationPDX {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(kTestLatPDX, kTestLongPDX);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coord  altitude:kTestAlt horizontalAccuracy:kTestHorizontalAccuracy verticalAccuracy:kTestVerticalAccuracy timestamp:[NSDate date]];
    return [location autorelease];
}

+ (CLLocation*)testLocationSFO {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(kTestLatSFO, kTestLongSFO);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coord altitude:kTestAlt horizontalAccuracy:kTestHorizontalAccuracy verticalAccuracy:kTestVerticalAccuracy timestamp:[NSDate date]];
    return [location autorelease];                            
}


+ (CLLocationManager*)testLocationManager {
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.desiredAccuracy = kTestDesiredAccuracy;
    manager.distanceFilter = kTestDistanceFilter;
    return [manager autorelease];
}
@end
