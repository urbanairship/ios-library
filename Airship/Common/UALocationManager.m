/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "UALocationManager.h"
#import "UAGlobal.h"

@interface UALocationManager ()
- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices;
@end

@implementation UALocationManager

@synthesize locationManager = locationManager_;
@synthesize currentStatus = currentStatus_;
@synthesize backgroundLocationMonitoringEnabled = backgroundLocationMonitoringEnabled_;

#pragma mark -
#pragma Object Lifecycle

- (void)dealloc{
    RELEASE_SAFELY(locationManager_);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if(self){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        backgroundLocationMonitoringEnabled_ = NO;
    }
    return self;
}

#pragma mark -
#pragma CLLocationManager property accessors

- (CLLocationAccuracy)desiredAccuracy {
    return locationManager_.desiredAccuracy;
}

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    locationManager_.desiredAccuracy = desiredAccuracy;
}

- (CLLocationDistance)distanceFilter {
    return locationManager_.distanceFilter;
}

- (void)setDistanceFilter:(CLLocationDistance)distanceFilter {  
    locationManager_.distanceFilter = distanceFilter;
}

#pragma mark -
#pragma Location Updating

- (void)startUpdatingLocation {
    if (![self checkAuthorizationAndAvailabiltyOfLocationServices]) return;
    [locationManager_ startUpdatingLocation];
    currentStatus_ = UALocationManagerUpdating;
}

- (void)stopUpdatingLocation {
    [locationManager_ stopUpdatingLocation];
    currentStatus_ = UALocationManagerNotUpdating;
}

#pragma mark -
#pragma CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {

}

#pragma mark -
#pragma Automatic Standard Location Updates

- (BOOL)enableAutomaticStandardLocationUpdates {
    if (![self checkAuthorizationAndAvailabiltyOfLocationServices]) return NO;
    return NO;
}

#pragma mark -
#pragma CLLocationManager authorization/location services settings

/** Checks both locationServicesEnabled and authorizationStatus
 *  for CLLocationManager an records state of appropriate flags.
 *  Returns:
 *      YES if locationServicesAreEnabled and kCLAuthorizationStatusAuthorized
 *      NO in all other cases
 *
 */
- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices {
    if (![CLLocationManager locationServicesEnabled]) {
        currentStatus_ = UALocationManagerNotEnabled;
        return NO;
    }
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorized) {
        currentStatus_ = UALocationManagerNotAuthorized;
        return NO;
    }
    return YES;
}





@end
