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

#import <CoreLocation/CoreLocation.h>
#import "UALocationService.h"
#import "UABaseLocationProvider.h"

@class UALocationEvent;
@interface UALocationService () {
    UAStandardLocationProvider *standardLocationProvider_;
    UAStandardLocationProvider *singleLocationProvider_;   
    UASignificantChangeProvider *significantChangeProvider_;
}
// Override property declarations for implementation and testing
//
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@property (nonatomic, retain) NSDate *dateOfLastLocation;
//

// Sets appropriate value in NSUserDefaults
+ (void)setObject:(id)value forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
// gets values out of location service
+ (id)objectForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
// Sets appropriate bool in NSUserDefaults
+ (void)setBool:(BOOL)boolValue forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
+ (BOOL)boolForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
// Wrap the double in a number;
+ (void)setDouble:(double)value forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
+ (double)doubleForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
// CLLocationManager values in NSUserDefaults
// Basically wrapped double values
- (CLLocationAccuracy)desiredAccuracyForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key; 
- (CLLocationDistance)distanceFilterForLocationSerivceKey:(UALocationServiceNSDefaultsKey*)key;
// Private setters for location providers
// Custom get/set methods that have the side effect of setting the provider delegate
- (UAStandardLocationProvider*)standardLocationProvider;
- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider;
- (UASignificantChangeProvider*)significantChangeProvider;
- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider;
- (UAStandardLocationProvider*)singleLocationProvider;
- (void)setSingleLocationProvider:(UAStandardLocationProvider*)singleLocationProvider;
// convinence method to set properties common to all providers
- (void)setCommonPropertiesOnProvider:(UABaseLocationProvider*)locationProvider;
// convienence method for calling enabled and authorized
- (BOOL)isLocationServiceEnabledAndAuthorized;
// UIApplicationState observation
- (void)beginObservingUIApplicationState;
// Restart locaiton services if necessary, call single location if necessary
- (void)appWillEnterForeground; 
// Shutdown location services if not enabled. 
- (void)appDidEnterBackground;
// Checks the elapsed time and other variables to decide whether a foreground report is needed
- (BOOL)shouldPerformAutoLocationUpdate;
// Convinence method to check authorization before starting provider
- (void)startReportingLocationWithProvider:(id)locationProvider;
// Send the error to the delegate if it responds
- (void)sendErrorToLocationServiceDelegate:(NSError*)error;

@end
