//
//  UALocationTestUtils.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/20/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

#define kTestLat 45.525352839897
#define kTestLong -122.682115697712
#define kTestAlt 100.0
#define kTestHorizontalAccuracy 5.0
#define kTestVerticalAccuracy 5.0
#define kTestDistanceFilter 10.0
#define kTestDesiredAccuracy 5.0

@interface UALocationTestUtils : NSObject

/** Creates and returns a location with the above values */
+ (CLLocation*)getTestLocation;
/** Creates and returns a location manager with the above values */
+ (CLLocationManager*)getTestLocationManager;
@end
