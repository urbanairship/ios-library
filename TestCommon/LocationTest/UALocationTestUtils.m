//
//  UALocationTestUtils.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/20/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationTestUtils.h"

@implementation UALocationTestUtils

+ (CLLocation*)getTestLocation {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(kTestLat, kTestLong);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:coord  altitude:kTestAlt horizontalAccuracy:kTestHorizontalAccuracy verticalAccuracy:kTestVerticalAccuracy timestamp:[NSDate date]];
    return [location autorelease];
}

+ (CLLocationManager*)getTestLocationManager {
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.desiredAccuracy = kTestDesiredAccuracy;
    manager.distanceFilter = kTestDistanceFilter;
    return [manager autorelease];
}
@end
