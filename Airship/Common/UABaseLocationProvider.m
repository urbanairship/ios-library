/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

#import "UALocationServicesCommon.h"
#import "UABaseLocationProvider.h"
#import "UAGlobal.h"
#import "UAEvent.h"
#import "UALocationUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"

@implementation UABaseLocationProvider

@synthesize locationManager = locationManager_;
@synthesize serviceStatus = serviceStatus_;
@synthesize delegate = delegate_;
@synthesize provider = provider_;

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    RELEASE_SAFELY(locationManager_);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        provider_ = UALocationServiceProviderUNKNOWN;
        serviceStatus_ = UALocationProviderNotUpdating;
    }
    return self;
}

- (id)initWithDelegate:(id<UALocationProviderDelegate>) delegate {
    self = [self init];
    if (self && [delegate conformsToProtocol:@protocol(UALocationProviderDelegate)]) {
        delegate_ = delegate;
    }
    return self;
}

#pragma mark -
#pragma mark Purpose Accessors

- (void)setPurpose:(NSString *)purpose_ {
    locationManager_.purpose = purpose_;
}

- (NSString*)purpose {
    return locationManager_.purpose;
}

#pragma mark -
#pragma mark CLLocationManager Accessors

- (void)setLocationManager:(CLLocationManager *)locationManager {
    [locationManager_ autorelease];
    locationManager_ = [locationManager retain];
    locationManager.delegate = self;
}



#pragma mark -
#pragma mark Location Accuracy calculations

- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)newLocation from:(CLLocation*)oldLocation {
    // accuracy values less than zero represent invalid lat/long values
    // If altitude becomes important in the future, add the check here for verticalAccuracy
    if (newLocation.horizontalAccuracy < 0) {
        return NO;
    }
    return YES;
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
    
    /** iOS 4.2 or better */
    // This is the nuclear option. Subclasses should implement specific action
    // TODO: Send analytics event if location service is denied?
    - (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
        if (status != kCLAuthorizationStatusAuthorized) {
            [locationManager_ stopUpdatingHeading];
            [locationManager_ stopUpdatingLocation];
            [locationManager_ stopMonitoringSignificantLocationChanges];
        }
        [delegate_ UALocationProvider:self withLocationManager:locationManager_ didChangeAuthorizationStatus:status];
    }
    
    
    - (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
        [delegate_ UALocationProvider:self withLocationManager:locationManager_ didFailWithError:error];
    }
    
    - (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
        if ([self locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation]) {
            [delegate_ UALocationProvider:self withLocationManager:locationManager_ didUpdateLocation:newLocation fromLocation:oldLocation];
        }
    }
    
    @end
