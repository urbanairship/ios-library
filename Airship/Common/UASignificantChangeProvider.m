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

@implementation UASignificantChangeProvider

- (id)init {
    self = [super init];
    if (self) {
        provider_ = UALocationServiceProviderNETWORK;
    }
    return self;
}


#pragma mark -
#pragma mark CLLocationManager Delegate
//** iOS 4.2 or better */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status != kCLAuthorizationStatusAuthorized) {
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

#pragma mark -
#pragma mark Location Accuracy

// Take any location when recieving a significant change
- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)newLocation from:(CLLocation*)oldLocation {
    // return any valid location since we will not get multiple calls
    return [super locationChangeMeetsAccuracyRequirements:newLocation from:oldLocation];
}

- (void)startProvidingLocation {
    [super startProvidingLocation];
    [locationManager_ startMonitoringSignificantLocationChanges];
}
- (void)stopProvidingLocation {
    [super stopProvidingLocation];
    [locationManager_ stopMonitoringSignificantLocationChanges];
}

+ (UASignificantChangeProvider*)providerWithDelegate:(id<UALocationProviderDelegate>)delegateOrNil {
    return [[[UASignificantChangeProvider alloc] initWithDelegate:delegateOrNil] autorelease];
}
@end
