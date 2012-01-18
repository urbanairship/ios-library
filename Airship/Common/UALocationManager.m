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
#import "UASingleLocationAcquireAndUpload.h"
#import "UALocationManger_Private.h"

@implementation UALocationManager

@synthesize locationManager = locationManager_;
@synthesize standardLocationActivityStatus = standardLocationActivityStatus_;
@synthesize significantChangeActivityStatus = significantChangeActivityStatus_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize backgroundLocationMonitoringEnabled = backgroundLocationMonitoringEnabled_;
@synthesize delegate = delegate_;
@synthesize singleLocationUpload = singleLocationUpload_;

#pragma mark -
#pragma Object Lifecycle

- (void)dealloc{
    RELEASE_SAFELY(locationManager_);
    RELEASE_SAFELY(lastReportedLocation_);
    [self stopObservingUIApplicationStateNotifications];
    [super dealloc];
}

- (id)initWithDelegateOrNil:(id<UALocationServicesDelegate>)delegateOrNil {
    self = [super init];
    if(self){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        backgroundLocationMonitoringEnabled_ = NO;
        standardLocationActivityStatus_ = UALocationServiceNotUpdating;
        significantChangeActivityStatus_ = UALocationServiceNotUpdating;
        delegate_ = delegateOrNil;
    }
    return self;
}

#pragma mark -
#pragma CLLocationManager forwarding

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


- (BOOL)startStandardLocationUpdates {
    if (![self checkAuthorizationAndAvailabiltyOfLocationServices]) {
        return NO;
    }
    [locationManager_ startUpdatingLocation];
    standardLocationActivityStatus_ = UALocationServiceUpdating;
    return YES;
}

- (void)stopStandardLocationUpdates {
    [locationManager_ stopUpdatingLocation];
    standardLocationActivityStatus_ = UALocationServiceNotUpdating;
}

- (BOOL)startSignificantChangeLocationUpdates {
    if(![self checkAuthorizationAndAvailabiltyOfLocationServices]){
        return NO;
    }
    [locationManager_ startMonitoringSignificantLocationChanges];
    significantChangeActivityStatus_ = UALocationServiceUpdating;
    return YES ;
}

- (void)stopSignificantChangeLocationUpdates {
    [locationManager_ stopMonitoringSignificantLocationChanges];
    significantChangeActivityStatus_ = UALocationServiceNotUpdating;
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

- (void)stopAllLocationUpdates {
    [self stopStandardLocationUpdates];
    [self stopSignificantChangeLocationUpdates];
}

#pragma mark -
#pragma CLLocationManagerDelegate

// Shutdown location services if authorization changes
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status != kCLAuthorizationStatusAuthorized) {
        [self stopAllLocationUpdates];
        
        // TODO: figure out what to do if single service is in the middle of processing
        // maybe post a notification? Probably do nothing, but check for possible failure
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (delegate_ && [delegate_ conformsToProtocol:@protocol(UALocationServicesDelegate)]) {
        if([delegate_ respondsToSelector:@selector(uaLocationManager:locationManager:didFailWithError:)]){
            [delegate_ uaLocationManager:self locationManager:manager didFailWithError:error];
        }
    }
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

- (BOOL)acquireSingleLocationAndUpload {
    singleLocationUpload_ = [[UASingleLocationAcquireAndUpload alloc] initWithDelegate:self];
    singleLocationUpload_.locationManager.distanceFilter = locationManager_.distanceFilter;
    singleLocationUpload_.locationManager.desiredAccuracy = locationManager_.desiredAccuracy;
    return [singleLocationUpload_ acquireAndSendLocation];
}

- (void)uaLocationManager:(id)UALocationServiceObject 
          locationManager:(CLLocationManager*)locationManager 
         didFailWithError:(NSError*)error {
    //Handle error from our one shot
}

#pragma mark -
#pragma UIApplication State Observation

- (void)startObservingUIApplicationStateNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(receivedUIApplicationWillEnterForegroundNotification) 
                                                 name:UIApplicationWillEnterForegroundNotification 
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(receivedUIApplicationDidEnterBackgroundNotification) 
                                                 name:UIApplicationDidEnterBackgroundNotification 
                                               object:[UIApplication sharedApplication]];
}

- (void)stopObservingUIApplicationStateNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
}

- (void)receivedUIApplicationDidEnterBackgroundNotification {
    NSLog(@"BACKGROUND");
}

- (void)receivedUIApplicationWillEnterForegroundNotification {
    NSLog(@"FOREGROUND");
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
