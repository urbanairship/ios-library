/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
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
}

- (instancetype)init {
    self = [super init];
    if (self){
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.provider = UALocationServiceProviderUnknown;
        self.serviceStatus = UALocationProviderNotUpdating;
        self.maximumElapsedTimeForCachedLocation = kDefaultMaxCachedLocationAgeSeconds;
    }
    return self;
}

- (instancetype)initWithDelegate:(id<UALocationProviderDelegate>)delegate {
    self = [self init];
    if (self && [delegate conformsToProtocol:@protocol(UALocationProviderDelegate)]) {
        self.delegate = delegate;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Provider:%@, Purpose:%@, Updating:%ld, desiredAccuracy %f, distanceFilter %f", 
            self.provider,
            self.purpose,
            (long)self.serviceStatus,
            self.locationManager.desiredAccuracy,
            self.locationManager.distanceFilter];
}

#pragma mark -
#pragma mark CLLocationManager Accessors

- (void)setLocationManager:(CLLocationManager *)locationManager {
    _locationManager = locationManager;
    _locationManager.delegate = self;
    self.serviceStatus = UALocationProviderNotUpdating;
}

- (NSString *)purpose {
    NSDictionary *infoDict = NSBundle.mainBundle.infoDictionary;
    NSString *purpose = [infoDict objectForKey:@"NSLocationUsageDescription"];
    return purpose;
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
// Allows for consolodation of didFailWithError and didUpdateLocations and
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
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            [self stopAllReporting];
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusNotDetermined:
        default:
            break;
    }

    id<UALocationProviderDelegate> strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationProvider:withLocationManager:didChangeAuthorizationStatus:)]){
        [strongDelegate locationProvider:self withLocationManager:self.locationManager didChangeAuthorizationStatus:status];
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

    id<UALocationProviderDelegate> strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(locationProvider:withLocationManager:didFailWithError:)]) {
        [strongDelegate locationProvider:self withLocationManager:self.locationManager didFailWithError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    id<UALocationProviderDelegate> strongDelegate = self.delegate;
    BOOL doesRespond = [strongDelegate respondsToSelector:@selector(locationProvider:withLocationManager:didUpdateLocations:)];
    if ([self locationChangeMeetsAccuracyRequirements:[locations lastObject]] && doesRespond) {
        [strongDelegate locationProvider:self withLocationManager:manager didUpdateLocations:locations];
    }
}

#pragma mark -
#pragma mark Location Accuracy calculations

- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation *)newLocation {
    // Throw out old values
    NSTimeInterval old = -[newLocation.timestamp timeIntervalSinceNow];
    if (old > self.maximumElapsedTimeForCachedLocation) {
        return NO;
    }
    
    // accuracy values less than zero represent invalid lat/long values
    // If altitude becomes important in the future, add the check here for verticalAccuracy
    if (newLocation.horizontalAccuracy < 0) {
        UA_LTRACE(@"Location %@ did not met accuracy requirements", newLocation);
        return NO;
    }
    
    return YES;
}

@end
