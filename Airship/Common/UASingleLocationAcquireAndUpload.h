//
//  UASingleLocationAcquireAndUplaod.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesDelegate.h"
#import "UALocationServices.h"


/** This class is designed to provide Urban Airship with a single
 *  location on demand.
 */

@interface UASingleLocationAcquireAndUpload : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *locationManager_;
    UALocationManagerServiceActivityStatus serviceStatus_;
    id <UALocationServicesDelegate> delegate_;
}
@property (nonatomic, retain, readonly) CLLocationManager *locationManager;
@property (nonatomic, assign, readonly) UALocationManagerServiceActivityStatus serviceStatus;
@property (nonatomic, assign) id <UALocationServicesDelegate> delegate;

- (id)initWithDelegate:(id<UALocationServicesDelegate>)delegateOrNil;

// KVO compliant methods to pass settings to CLLocationManager
- (CLLocationAccuracy)desiredAccuracy;
- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy;

- (CLLocationDistance)distanceFilter;
- (void)setDistanceFilter:(CLLocationDistance)distanceFilter;

/** Acquires a location using the Standard Location service.
 *  
 */
- (BOOL)acquireAndSendLocationToUA;
@end
