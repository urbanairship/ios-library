//
//  CLLocationManager+CLLocationManager_Test.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

@interface CLLocationManager (Test)
+ (BOOL)returnYES;
+ (BOOL)returnNO;
+ (CLAuthorizationStatus)returnCLLocationStatusAuthorized;
+ (CLAuthorizationStatus)returnCLLocationStatusDenied;
+ (CLAuthorizationStatus)returnCLLocationStatusRestricted;
+ (CLAuthorizationStatus)returnCLLocationStatusNotDetermined;
- (void)sendAuthorizationChangedDelegateCallWithAuthorization:(CLAuthorizationStatus)status;
- (void)sendLocationDidFailWithErrorDelegateCallWithError:(NSError*)error;
- (void)sendDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation;
@end
