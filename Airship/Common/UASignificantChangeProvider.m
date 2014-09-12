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

#import "UASignificantChangeProvider.h"
#import "UAGlobal.h"

@implementation UASignificantChangeProvider

- (void)dealloc {
    
    self.delegate = nil;
    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.locationManager.delegate = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.provider = UALocationServiceProviderNetwork;
    }
    return self;
}


#pragma mark -
#pragma mark CLLocationManager Delegate
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            [self stopReportingLocation];
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusNotDetermined:
        default:
            break;
    }
    [self.delegate locationProvider:self withLocationManager:self.locationManager didChangeAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    id<UALocationProviderDelegate> strongDelegate = self.delegate;
    BOOL doesRespond = [strongDelegate respondsToSelector:@selector(locationProvider:withLocationManager:didUpdateLocations:)];
    if ([self locationChangeMeetsAccuracyRequirements:[locations lastObject]] && doesRespond) {
        [strongDelegate locationProvider:self withLocationManager:manager didUpdateLocations:locations];
    }
}

#pragma mark -
#pragma mark Location Accuracy


- (void)startReportingLocation {
    [super startReportingLocation];
    [self.locationManager startMonitoringSignificantLocationChanges];
}
- (void)stopReportingLocation {
    UA_LDEBUG(@"Stop reporting significant change service");
    [super stopReportingLocation];
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

+ (UASignificantChangeProvider *)providerWithDelegate:(id<UALocationProviderDelegate>)delegateOrNil {
    return [[UASignificantChangeProvider alloc] initWithDelegate:delegateOrNil];
}
@end
