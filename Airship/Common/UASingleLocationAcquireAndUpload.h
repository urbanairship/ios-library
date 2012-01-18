//
//  UASingleLocationAcquireAndUplaod.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesCommon.h"


/** This class is designed to provide Urban Airship with a single
 *  location on demand.
 */
@class UALocationUtils;
@interface UASingleLocationAcquireAndUpload : NSObject <CLLocationManagerDelegate, UALocationAnalyticsProtocol> {
    @private
    CLLocationManager *locationManager_;
    UALocationManagerServiceActivityStatus serviceStatus_;
    id <UALocationServicesDelegate> delegate_;
}
@property (nonatomic, retain, readonly) CLLocationManager *locationManager;
@property (nonatomic, assign, readonly) UALocationManagerServiceActivityStatus serviceStatus;
@property (nonatomic, assign) id <UALocationServicesDelegate> delegate;
/** These properties forward calls to the CLLocationManager */
@property (nonatomic, assign) CLLocationAccuracy desiredAccuracy;
@property (nonatomic, assign) CLLocationDistance distanceFilter;
/***/

- (id)initWithDelegate:(id<UALocationServicesDelegate>)delegateOrNil;

/** Acquires a location using the Standard Location service.
 *  If the service is already in process, this method returns
 *  YES. 
 */
- (BOOL)acquireAndSendLocation;


@end
