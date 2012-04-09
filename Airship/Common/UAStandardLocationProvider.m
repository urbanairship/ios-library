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
#import "UAStandardLocationProvider.h"
#import "UALocationCommonValues.h"
#import "UAGlobal.h"

@implementation UAStandardLocationProvider
@synthesize lastReceivedLocation = lastRecievedLocation_;

- (void)dealloc {
    RELEASE_SAFELY(lastRecievedLocation_);
    self.delegate = nil;
    // Directly stop the location mananger for speed and clarity
    [locationManager_ stopUpdatingLocation];
    locationManager_.delegate = nil;
    // Super class deallocates location manager
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        provider_ = UALocationServiceProviderGps; 
    }
    return self;
}

#pragma mark -
#pragma mark CLLocationDelegate Methods

//** iOS 4.2 or better */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UALOG(@"Standard location authorization changed %d", status);
    switch (status) {
        case kCLAuthorizationStatusAuthorized:
            break;
        case kCLAuthorizationStatusNotDetermined:
            break;
        case kCLAuthorizationStatusDenied:
            [self stopReportingLocation];
            break;
        case kCLAuthorizationStatusRestricted:
            [self stopReportingLocation];
            break;
        default:
            break;
    }
    [delegate_ locationProvider:self withLocationManager:manager didChangeAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    UALOG(@"Standard location mananager did fail with error %@", error.description);
    [delegate_ locationProvider:self withLocationManager:manager didFailWithError:error];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    UALOG(@"Standard location manager did update to location %@ from location %@", newLocation, oldLocation);
    if([self locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation]) {
        self.lastReceivedLocation = newLocation;
        [delegate_ locationProvider:self withLocationManager:manager didUpdateLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark Location Reporting

- (void)startReportingLocation {
    UALOG(@"Start standard location");
    [super startReportingLocation];
    [locationManager_ startUpdatingLocation];
}
- (void)stopReportingLocation {
    UALOG(@"Stop standard location");
    [super stopReportingLocation];
    [locationManager_ stopUpdatingLocation];
}
 
+ (UAStandardLocationProvider*)providerWithDelegate:(id<UALocationProviderDelegate>)serviceDelegateOrNil {
    return [[[UAStandardLocationProvider alloc] initWithDelegate:serviceDelegateOrNil] autorelease];
}
@end
