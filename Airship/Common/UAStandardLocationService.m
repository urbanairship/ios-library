//
//  UABaseLocationService.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UAStandardLocationService.h"
#import "UAGlobal.h"

@implementation UAStandardLocationService
@synthesize locationManager = locationManager_;

- (void)dealloc {
    RELEASE_SAFELY(locationManager_);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        locationManager_ = [[CLLocationManager alloc] init];
    }
    return self;
}
-(id)initWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy andDistanceFilter:(CLLocationDistance)distanceFilter{
    self = [self init];
    if (self){
        locationManager_.distanceFilter = distanceFilter;
        locationManager_.desiredAccuracy = desiredAccuracy;
    }
    return self;
}

- (void)startLocationService {
    [locationManager_ stopUpdatingLocation];
}

- (void)stopLocationService {
    [locationManager_ stopUpdatingLocation];
}

@end
