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

#import "UAGlobal.h"
#import "UALocationServiceManager.h"
#import "UALocationServiceManager_Private.h"
#import "UALocationServices.h"


@implementation UALocationServiceManager
@synthesize locationService = locationService_;
@synthesize delegate = delegate_;
@synthesize serviceStatus = serviceStatus_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize lastLocationAttempt = lastLocationAttempt_;
@synthesize backgroundLocationServiceEnabled = backgroundLocationServiceEnabled_;
@synthesize updateLocationAtLaunch = updateLocationAtLaunch_;

- (void)dealloc {
    RELEASE_SAFELY(locationService_);
    [super dealloc];
}

- (id)initWithLocationService:(id <UALocationService>) locationService {
    self = [super init];
    if (self){
        locationService_ = [locationService retain];
        locationService_.locationManager.delegate = self;
    }
    return self;
}

#pragma mark -
#pragma mark CLLocationManagerDelegate

// Shutdown location services if authorization changes
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status != kCLAuthorizationStatusAuthorized) {
        [locationService_ stopLocationService];
        serviceStatus_ =  UALocationServiceNotUpdating;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (delegate_ && [delegate_ conformsToProtocol:@protocol(UALocationServiceDelegate)]) {
        if([delegate_ respondsToSelector:@selector(uaLocationManager:locationManager:didFailWithError:)]){
            [delegate_ uaLocationManager:self locationManager:manager didFailWithError:error];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    //TODO:  Figure out location accuracy algorithm
    if (newLocation.horizontalAccuracy < locationService_.locationManager.desiredAccuracy || 
        locationService_.locationManager.desiredAccuracy < 0) {
        self.lastReportedLocation = newLocation;
    }
    //TODO: added functionality and API calls
}

#pragma mark -
#pragma mark Location Services

- (BOOL)startLocationServices {
    if ([self checkAuthorizationAndAvailabiltyOfLocationServices]) {
        [locationService_ startLocationService];
        serviceStatus_ = UALocationServiceUpdating;
        return YES;
    }
    return NO;
}

- (void)stopLocationServices {
    [locationService_ stopLocationService];
    serviceStatus_ = UALocationServiceNotUpdating;
}

#pragma mark -
#pragma mark CLLocationManager authorization/location services settings

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

#pragma mark -
#pragma mark UIApplication State Observation

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
    if (!backgroundLocationServiceEnabled_){
        [locationService_ stopLocationService];
    }
}

- (void)receivedUIApplicationWillEnterForegroundNotification {
    if (updateLocationAtLaunch_) {
        [UALocationServices acquireSingleLocationAndUpload];
    }
}


@end
