//
//  UASignificantChangeLocationService.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UASignificantChangeLocationService.h"

@implementation UASignificantChangeLocationService

- (void)startLocationService {
    [locationManager_ startMonitoringSignificantLocationChanges];
}
- (void)stopLocationService {
    [locationManager_ stopMonitoringSignificantLocationChanges];
}

@end
