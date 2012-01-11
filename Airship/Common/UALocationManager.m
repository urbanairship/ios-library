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
- (void)startObservingUIApplicationStateNotifications;
- (void)stopObservingUIApplicationStateNotifications;
- (BOOL)testAccuracyOfLocation:(CLLocation*)newLocation;
- (void)updateLastLocation:(CLLocation*)newLocation;

@property (nonatomic, assign) UALocationManagerActivityStatus locationManagerActivityStatus;
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@end

@implementation UALocationManager

@synthesize locationManager = locationManager_;
@synthesize singleServiceLocationManager = singleServiceLocationManager_;
@synthesize locationManagerActivityStatus = locationManagerActivityStatus_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize backgroundLocationMonitoringEnabled = backgroundLocationMonitoringEnabled_;

#pragma mark -
#pragma Object Lifecycle

- (void)dealloc{
    RELEASE_SAFELY(locationManager_);
    RELEASE_SAFELY(singleServiceLocationManager_);
    RELEASE_SAFELY(lastReportedLocation_);
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

//TODO: setup these methods to change settings for 
// all the managers

- (CLLocationAccuracy)desiredAccuracyForStandardLocationService {
    return locationManager_.desiredAccuracy;
}

- (void)setDesiredAccuracyForStandardLocationService:(CLLocationAccuracy)desiredAccuracy {
   locationManager_.desiredAccuracy = desiredAccuracy;
}

- (CLLocationDistance)distanceFilterForStandardLocationService {
    return locationManager_.distanceFilter;
}

- (void)setDistanceFilterForStandardLocationService:(CLLocationDistance)distanceFilter {  
    locationManager_.distanceFilter = distanceFilter;
}



#pragma mark -
#pragma Location Updating


- (BOOL)startStandardLocationUpdates {
    if (![self checkAuthorizationAndAvailabiltyOfLocationServices]) {
        return NO;
    }
    [locationManager_ startUpdatingLocation];
    locationManagerActivityStatus_ = UALocationManagerUpdating;
    return YES;
}

- (void)stopStandardLocationUpdates {
    [locationManager_ stopUpdatingLocation];
    locationManagerActivityStatus_ = UALocationManagerNotUpdating;
}

- (BOOL)startSignificantChangeLocationUpdates {
    return NO;
}

- (void)stopSignificantChangeLocationUpdates {

}

// TODO: change this method to take more parameters to handle 
// differing location requirements of the different location managers
- (BOOL)testAccuracyOfLocation:(CLLocation*)newLocation {

    CLLocationAccuracy accuracyOfLocation = newLocation.horizontalAccuracy;
    if (accuracyOfLocation < locationManager_.desiredAccuracy) {
        [self updateLastLocation:newLocation];
        return YES;
    }
    return NO;
}
// TODO: Start here and come up with a basic algorithm to check status of returned
// location
- (void)updateLastLocation:(CLLocation*)newLocation {
    if (nil != lastReportedLocation_) [lastReportedLocation_ autorelease];
    lastReportedLocation_ = [newLocation retain];
}

#pragma mark -
#pragma CLLocationManagerDelegate

// Shutdown location services if authorization changes
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status != kCLAuthorizationStatusAuthorized) {
        // Changes this to accomodate all of the CLLocationManagers
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {

    // TODO: send a notification? what action should be taken?
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (nil != lastReportedLocation_) [lastReportedLocation_ autorelease];
    lastReportedLocation_ = [newLocation retain];  
    // TODO: added functionality and API calls
}


#pragma mark -
#pragma Automatic Standard Location Updates

- (BOOL)enableAutomaticStandardLocationUpdates {
    if (![self checkAuthorizationAndAvailabiltyOfLocationServices]) return NO;
    return NO;
}

- (void)disableAutomaticStandardLocationUpdates {
    
}

#pragma mark -
#pragma Single Location

- (BOOL)acquireSingleLocationAndUploadToUrbanAirship {
    return NO;
}

#pragma mark -
#pragma UIApplication State Observation

- (void)startObservingUIApplicationStateNotifications {
    
}

- (void)stopObservingUIApplicationStateNotifications {
    
}

#pragma mark -
#pragma CLLocationManager authorization/location services settings

/** Checks both locationServicesEnabled and authorizationStatus
 *  for CLLocationManager an records state of appropriate flags.
 *  Returns:
 *      YES if locationServicesAreEnabled and kCLAuthorizationStatusAuthorized
 *      NO in all other cases
 */
- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices {
    if (![CLLocationManager locationServicesEnabled]) return NO;
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorized) return NO;
    return YES;
}


@end
