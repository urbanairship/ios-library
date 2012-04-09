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
    BOOL shouldStartReportingStandardLocation_;
    BOOL shouldStartReportingSignificantChange_;
    CLLocation *bestAvailableStandardLocation_;
    CLLocation *bestAvailableSingleLocation_;
}
// Override property declarations for implementation and testing
//
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@property (nonatomic, retain) NSDate *dateOfLastLocation;
@property (nonatomic, assign) BOOL shouldStartReportingStandardLocation;
@property (nonatomic, assign) BOOL shouldStartReportingSignificantChange;
/* Keep a record of the location with the highest horizontalAccuracy in case
 the single location service times out before acquiring a location that meets
 accuracy requirements setup in desiredAccuracy
 */
@property (nonatomic, retain) CLLocation *bestAvailableStandardLocation;
@property (nonatomic, retain) CLLocation *bestAvailableSingleLocation;
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

// Restart any location services that were previously running
- (void)restartPreviousLocationServices;

// CLLocationManager values in NSUserDefaults
// Basically wrapped double values
- (CLLocationAccuracy)desiredAccuracyForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key; 
- (CLLocationDistance)distanceFilterForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;

// Private setters for location providers
// Custom get/set methods that have the side effect of setting the provider delegate
// This also sets the desiredAccuracy and distanceFilter from the standard defaults
- (UAStandardLocationProvider*)standardLocationProvider;
- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider;

// Side effect of setting the delegate
- (UASignificantChangeProvider*)significantChangeProvider;
- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider;

// This method also sets the delegate of the provider. 
// This method DOES NOT change the distanceFilter or desiredAccuracy
- (UAStandardLocationProvider*)singleLocationProvider;
- (void)setSingleLocationProvider:(UAStandardLocationProvider*)singleLocationProvider;

// convinence method to set properties common to all providers
// currently sets the delegate and purpose
- (void)setCommonPropertiesOnProvider:(id <UALocationProviderProtocol>)locationProvider;

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
// Has the side effect of setting the delegate on the provider to self if the 
// delegate is nil
- (void)startReportingLocationWithProvider:(id<UALocationProviderProtocol>)locationProvider;

// Send the error to the delegate if it responds
- (void)sendErrorToLocationServiceDelegate:(NSError*)error;

// deprecated LOCATION SUPPORT
// Use deprecated location calls
+ (BOOL)useDeprecatedMethods;

// Single Location update logic
- (void)singleLocationDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation;
// Shutdown service after location is received. If the passed in location is nil, the service is 
// shutdown, and an error is returned to the delegate
- (void)shutdownSingleLocationServiceAndSendLocation:(CLLocation*)location;

// Accuracy calculations
- (BOOL)locationProvider:(id<UALocationProviderProtocol>)provider 
            shouldReport:(CLLocation*)newLocation 
                    from:(CLLocation*)oldLocation;

// Shutdown timers for single and standard location
- (void)standardLocationTimedOut;
@end
