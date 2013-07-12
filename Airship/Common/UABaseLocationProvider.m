/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UABaseLocationProvider.h"
#import "UAGlobal.h"
#import "UAEvent.h"
#import "UAirship.h"
#import "UAAnalytics.h"

#define kDefaultMaxCachedLocationAgeSeconds 300.0;

@interface UABaseLocationProvider ()
// Stop reporting any location service
- (void)stopAllReporting;
@end

@implementation UABaseLocationProvider

#pragma mark -
#pragma mark Object Lifecycle/NSObject Methods

- (void)dealloc {
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    self.provider = nil;
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        self.locationManager = [[[CLLocationManager alloc] init] autorelease];
        self.locationManager.delegate = self;
        self.provider = UALocationServiceProviderUnknown;
        self.serviceStatus = UALocationProviderNotUpdating;
        self.maximumElapsedTimeForCachedLocation = kDefaultMaxCachedLocationAgeSeconds;
    }
    return self;
}

- (id)initWithDelegate:(id<UALocationProviderDelegate>)delegate {
    self = [self init];
    if (self && [delegate conformsToProtocol:@protocol(UALocationProviderDelegate)]) {
        self.delegate = delegate;
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"Provider:%@, Purpose:%@, Updating:%d, desiredAccuracy %f, distanceFilter %f", 
            self.provider,
            self.purpose,
            self.serviceStatus,
            self.locationManager.desiredAccuracy,
            self.locationManager.distanceFilter];
}

#pragma mark -
#pragma mark CLLocationManager Accessors

- (void)setLocationManager:(CLLocationManager *)locationManager {
    [_locationManager autorelease];
    _locationManager = [locationManager retain];
    _locationManager.delegate = self;
    self.serviceStatus = UALocationProviderNotUpdating;
}

- (void)setPurpose:(NSString *)purpose {
    if (purpose) {
        self.locationManager.purpose = purpose;
    }
}

- (NSString *)purpose {
    return self.locationManager.purpose;
}

- (CLLocationDistance)distanceFilter {
    return self.locationManager.distanceFilter;
}

- (void)setDistanceFilter:(CLLocationDistance)distanceFilter{
    self.locationManager.distanceFilter = distanceFilter;
}

- (CLLocationAccuracy)desiredAccuracy{
    return self.locationManager.desiredAccuracy;
}

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy{
    self.locationManager.desiredAccuracy = desiredAccuracy;
}

- (CLLocation*)location {
    return self.locationManager.location;
}

#pragma mark -
#pragma mark UALocationProviderProtocol empty methods

// Methods only update the location status
// Allows for consolodation of didFailWithError and didUpateToLocation and
// delegate callbacks here
- (void)startReportingLocation {
    self.serviceStatus = UALocationProviderUpdating;
}    

- (void)stopReportingLocation {
    self.serviceStatus = UALocationProviderNotUpdating;
}
    
#pragma mark -
#pragma mark CLLocationManger Delegate
    
/* iOS 4.2 or better */
// This is the nuclear option. Subclasses should implement specific action
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusAuthorized:
            break;
        case kCLAuthorizationStatusNotDetermined:
            break;
        case kCLAuthorizationStatusDenied:
            [self stopAllReporting];
            break;
        case kCLAuthorizationStatusRestricted:
            [self stopAllReporting];
            break;
        default:
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(locationProvider:withLocationManager:didChangeAuthorizationStatus:)]){
        [self.delegate locationProvider:self withLocationManager:self.locationManager didChangeAuthorizationStatus:status];
    }
}

- (void)stopAllReporting {
    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.serviceStatus = UALocationProviderNotUpdating;
    UALOG(@"Stopped all reporting");
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // Catch kCLErrorDenied for iOS < 4.2. Also, catch the errors that would stop the service, vs. other
    // errors which would just indicate that the service is in a transient error state that might clear
    // up given time. 
    switch (error.code) {
        case kCLErrorDenied:
            [self stopReportingLocation];
            break;
        case kCLErrorNetwork:
            [self stopReportingLocation];
            break;
        default:
            break;
    }

    UALOG(@"UA Location Manager %@ did fail with error %@", [self class], error);
    if ([self.delegate respondsToSelector:@selector(locationProvider:withLocationManager:didFailWithError:)]) {
        [self.delegate locationProvider:self withLocationManager:self.locationManager didFailWithError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    UALOG(@"Base location manager did update to location %@ from location %@", newLocation, oldLocation);
    BOOL doesRespond = [self.delegate respondsToSelector:@selector(locationProvider:withLocationManager:didUpdateLocation:fromLocation:)];
    if ([self locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation] && doesRespond) {
        [self.delegate locationProvider:self withLocationManager:manager didUpdateLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark Location Accuracy calculations

- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation *)newLocation from:(CLLocation *)oldLocation {
    // Throw out old values
    NSTimeInterval old = -[newLocation.timestamp timeIntervalSinceNow];
    if (old > self.maximumElapsedTimeForCachedLocation) {
        return NO;
    }
    
    // accuracy values less than zero represent invalid lat/long values
    // If altitude becomes important in the future, add the check here for verticalAccuracy
    if (newLocation.horizontalAccuracy < 0) {
        UALOG(@"Location %@ did not met accuracy requirements", newLocation);
        return NO;
    }
    
    UALOG(@"Location %@ met accuracy requirements", newLocation);
    return YES;
}

@end
