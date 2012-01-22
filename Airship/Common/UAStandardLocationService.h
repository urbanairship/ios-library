//
//  UAStandardLocationService.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesCommon.h"

@interface UAStandardLocationService : NSObject <UALocationService> {
    @protected
    CLLocationManager *locationManager_;
}
@property (nonatomic, retain) CLLocationManager *locationManager;

/** Creates a CLLocationManager with default values for distanceFilter and desiredAccuracy */
- (id)init;
/** Passes the desiredAccuracy and distanceFilter to the CLLocationManager */
- (id)initWithDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy andDistanceFilter:(CLLocationDistance)distanceFilter;
/** Starts standard location service */
- (void)startLocationService;
/** Stops standard location service */
- (void)stopLocationService;
@end
