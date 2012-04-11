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

#import "UASignificantChangeProvider.h"
#import "UAGlobal.h"

@implementation UASignificantChangeProvider

- (void)dealloc {
    
    self.delegate = nil;
    [locationManager_ stopMonitoringSignificantLocationChanges];
    locationManager_.delegate = nil;
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        provider_ = UALocationServiceProviderNetwork;
    }
    return self;
}


#pragma mark -
#pragma mark CLLocationManager Delegate
//** iOS 4.2 or better */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UALOG(@"Significant change did change authorization status %d", status);
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
    [delegate_ locationProvider:self withLocationManager:locationManager_ didChangeAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    UALOG(@"Significant change did fail with error %@", error.description);
    [delegate_ locationProvider:self withLocationManager:manager didFailWithError:error];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    UALOG(@"Significant change did update to location %@ from location %@", newLocation, oldLocation);
    if ([self locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation]) {
        [delegate_ locationProvider:self withLocationManager:manager didUpdateLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark Location Accuracy


- (void)startReportingLocation {
    UALOG(@"Start significant change service");
    [super startReportingLocation];
    [locationManager_ startMonitoringSignificantLocationChanges];
}
- (void)stopReportingLocation {
    UALOG(@"Stop reporting significant change service");
    [super stopReportingLocation];
    [locationManager_ stopMonitoringSignificantLocationChanges];
}

+ (UASignificantChangeProvider*)providerWithDelegate:(id<UALocationProviderDelegate>)delegateOrNil {
    return [[[UASignificantChangeProvider alloc] initWithDelegate:delegateOrNil] autorelease];
}
@end
