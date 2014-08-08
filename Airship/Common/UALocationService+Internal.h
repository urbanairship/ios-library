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

#import <CoreLocation/CoreLocation.h>

#import "UALocationService.h"
#import "UABaseLocationProvider.h"


@class UALocationEvent;
@interface UALocationService () {

  @private
    UAStandardLocationProvider *_standardLocationProvider;
    UAStandardLocationProvider *_singleLocationProvider;
    UASignificantChangeProvider *_significantChangeProvider;

}

// Override property declarations for implementation and testing
//
@property (nonatomic, strong) CLLocation *lastReportedLocation;
@property (nonatomic, strong) NSDate *dateOfLastLocation;
@property (nonatomic, assign) BOOL shouldStartReportingStandardLocation;
@property (nonatomic, assign) BOOL shouldStartReportingSignificantChange;

/**
 * Keep a record of the location with the highest horizontalAccuracy in case
 * the single location service times out before acquiring a location that meets
 * accuracy requirements setup in desiredAccuracy
 */
@property (nonatomic, strong) CLLocation *bestAvailableSingleLocation;

/**
 * Background identifier for the singleLocationService
 */
@property (nonatomic, assign) UIBackgroundTaskIdentifier singleLocationBackgroundIdentifier;

/**
 * Value indicating that the single location service shutdown call has been scheduled for this
 * object with performSelector:withObject:afterDelay 
 */
@property (nonatomic, assign) BOOL singleLocationShutdownScheduled;

/**
 * Convenience method which set appropriate value in NSUserDefaults.
 */
+ (void)setObject:(id)value forLocationServiceKey:(UALocationServiceNSDefaultsKey *)key;

/**
 * Convenience method which retrieves values out of location service.
 */
+ (id)objectForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key;

// Sets appropriate bool in NSUserDefaults
+ (void)setBool:(BOOL)boolValue forLocationServiceKey:(UALocationServiceNSDefaultsKey *)key;

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
- (UAStandardLocationProvider *)standardLocationProvider;
- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider;

// Side effect of setting the delegate
- (UASignificantChangeProvider *)significantChangeProvider;
- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider;

// This method also sets the delegate of the provider. 
// This method DOES NOT change the distanceFilter or desiredAccuracy
- (UAStandardLocationProvider *)singleLocationProvider;
- (void)setSingleLocationProvider:(UAStandardLocationProvider*)singleLocationProvider;

// Convenience method to set properties common to all providers
// currently sets the delegate
- (void)setCommonPropertiesOnProvider:(id <UALocationProviderProtocol>)locationProvider;

// convenience method for calling enabled and authorized
- (BOOL)isLocationServiceEnabledAndAuthorized;

// UIApplicationState observation
- (void)beginObservingUIApplicationState;

// Restart location services if necessary, call single location if necessary
- (void)appWillEnterForeground; 

// Shutdown location services if not enabled. 
- (void)appDidEnterBackground;

// Checks the elapsed time and other variables to decide whether a foreground report is needed
- (BOOL)shouldPerformAutoLocationUpdate;

/**
 * Convenience method to check authorization before starting provider
 * Has the side effect of setting the delegate on the provider to self if the
 * delegate is nil.
 */
- (void)startReportingLocationWithProvider:(id<UALocationProviderProtocol>)locationProvider;

/**
 * Standard location location update
 */
- (void)standardLocationDidUpdateLocations:(NSArray *)locations;

/**
 * Sig change update method
 */
- (void)significantChangeDidUpdateLocations:(NSArray *)locations;

// Single Location update logic
- (void)singleLocationDidUpdateLocations:(NSArray *)location;

// Single Location when a good location is received
- (void)stopSingleLocationWithLocation:(CLLocation *)location;

// Stop single location when an error is returned, or the service timed out
- (void)stopSingleLocationWithError:(NSError *)locationError;

// Stop the single location service and cleanup the background task
// Do not call this directly, instead, use stopSingleLocationWithLocation
// or stopSingleLocationWithError
- (void)stopSingleLocation;

// Error indicating a location service timed out before getting a location that meets accuracy requirements
- (NSError *)locationTimeoutError;

// Shuts down the single location service with a timeout error
- (void)shutdownSingleLocationWithTimeoutError;


// This method registers the user defaults necessary for the UALocation Service. You should
// not need to call this method directly, it is called in UAirship.
+ (void)registerNSUserDefaults;
@end
