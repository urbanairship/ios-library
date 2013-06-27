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
#import "UAStandardLocationProvider.h"
#import "UALocationCommonValues.h"
#import "UAGlobal.h"

@implementation UAStandardLocationProvider

- (void)dealloc {
    self.delegate = nil;
    
    // Directly stop the location mananger for speed and clarity
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    
    // Super class deallocates location manager
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        self.provider = UALocationServiceProviderGps;
    }
    return self;
}

#pragma mark -
#pragma mark CLLocationDelegate Methods

//** iOS 4.2 or higher */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UALOG(@"Standard location authorization changed %d", status);
    switch (status) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            [self stopReportingLocation];
            break;
        case kCLAuthorizationStatusAuthorized:
        case kCLAuthorizationStatusNotDetermined:            
        default:
            break;
    }
    [self.delegate locationProvider:self withLocationManager:manager didChangeAuthorizationStatus:status];
}


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    UALOG(@"Standard location manager did update to location %@ from location %@", newLocation, oldLocation);
    BOOL doesRespond = [self.delegate respondsToSelector:@selector(locationProvider:withLocationManager:didUpdateLocation:fromLocation:)];
    if([self locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation] && doesRespond) {
        [self.delegate locationProvider:self withLocationManager:manager didUpdateLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark Location Reporting

- (void)startReportingLocation {
    UALOG(@"Start standard location");
    [super startReportingLocation];
    [self.locationManager startUpdatingLocation];
}
- (void)stopReportingLocation {
    UALOG(@"Stop standard location");
    [super stopReportingLocation];
    [self.locationManager stopUpdatingLocation];
}
 
+ (UAStandardLocationProvider *)providerWithDelegate:(id<UALocationProviderDelegate>)serviceDelegateOrNil {
    return [[[UAStandardLocationProvider alloc] initWithDelegate:serviceDelegateOrNil] autorelease];
}
@end
