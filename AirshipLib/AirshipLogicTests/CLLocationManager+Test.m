//
//  CLLocationManager+CLLocationManager_Test.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "CLLocationManager+Test.h"

// Add methods to CLLocationManager for swizzling
@implementation CLLocationManager (Test)
+ (BOOL)returnYES {
    return YES;
}
+ (BOOL)returnNO {
    return NO;
}
+ (CLAuthorizationStatus)returnCLLocationStatusAuthorized {
    return  kCLAuthorizationStatusAuthorized;
}
+ (CLAuthorizationStatus)returnCLLocationStatusDenied {
    return kCLAuthorizationStatusDenied;
}
+ (CLAuthorizationStatus)returnCLLocationStatusRestricted {
    return kCLAuthorizationStatusRestricted;
}
+ (CLAuthorizationStatus)returnCLLocationStatusNotDetermined {
    return kCLAuthorizationStatusNotDetermined;
}
- (void)sendAuthorizationChangedDelegateCallWithAuthorization:(CLAuthorizationStatus)status {
    [self.delegate locationManager:self didChangeAuthorizationStatus:status];
}

- (void)sendLocationDidFailWithErrorDelegateCallWithError:(NSError*)error {
    [self.delegate locationManager:self didFailWithError:error];
}

- (void)sendDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation {
    [self.delegate locationManager:self didUpdateToLocation:newLocation fromLocation:oldLocation];
}
@end
