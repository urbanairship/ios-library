//
//  UACLLocationManagerDelegate.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesCommon.h"

@interface UABaseLocationDelegate : NSObject <CLLocationManagerDelegate, UALocationDelegateProtocol> {
    CLLocationManager *locationManager_;
    id <UALocationServiceDelegate> delegate_;
    UALocationServiceStatus serviceStatus_;
    NSString *provider_;
}
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, assign) id <UALocationServiceDelegate> delegate;
@property (nonatomic, assign) UALocationServiceStatus serviceStatus;
/** Provider type must be set when either the Standard Location or 
 *  significant change location type is used since the delegate callbacks
 *  are the same. 
 */
@property (nonatomic, copy) NSString *provider;

- (id)init;
- (id)initWithDelegate:(id<UALocationServiceDelegate>) delegate;

/** Location accuracy */
- (BOOL)locationMeetsAccuracyRequirements:(CLLocation*)location;


@end
