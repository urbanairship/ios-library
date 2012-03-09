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
    NSMutableDictionary* locationServiceValues_;
    UAStandardLocationProvider *singleLocationProvider_;
    BOOL deprecatedLocation_;
}
// Override property declarations for implementation and testing
//
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@property (nonatomic, retain) NSDate *dateOfLastReport;
//

/* 
 Values written to disk each time they are set
 Values are stored as NSNumber objects.    
 */
@property (nonatomic, retain) NSDictionary *locationServiceValues;

// Indicates iOS < 4.2 and depricated method calls should be used
@property (nonatomic, assign) BOOL deprecatedLocation;

- (NSDictionary*)locationServiceValues;
// Sets appropriate value in NSUserDefaults
- (void)setValue:(id)value forLocationServiceKey:(NSString*)key;
// gets values out of location service
- (id)valueForLocationServiceKey:(NSString*)key;
// Sets appropriate bool in NSUserDefaults
- (void)setBool:(BOOL)boolValue forLocationServiceKey:(NSString*)key;
- (BOOL)boolForLocationServiceKey:(NSString*)key;
// Wrap the double in a number;
- (void)setDoubleValue:(double)value forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key;
// CLLocationManager values in NSUserDefaults
// Basically wrapped double values
- (CLLocationAccuracy)desiredAccuracyForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key; 
- (CLLocationDistance)distanceFilterForLocationSerivceKey:(UALocationServiceNSDefaultsKey*)key;
// Private setters for location providers
- (UAStandardLocationProvider*)standardLocationProvider;
- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider;
- (UASignificantChangeProvider*)significantChangeProvider;
- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider;
- (UAStandardLocationProvider*)singleLocationProvider;
- (void)setSingleLocationProvider:(UAStandardLocationProvider*)singleLocationProvider;
- (void)setCommonPropertiesOnProvider:(UABaseLocationProvider*)locationProvider;
//
// Updates UALocationServicesAllowed with current CLLocationManger values
// On iOS < 4.2, this is a no op, authorization is set with CLLocationManager callbacks
- (void)refreshLocationServiceAuthorization;
// Updates UALocationServiceAllowed when new
// CLAuthorizationStatus updates are received 
- (void)updateAllowedStatus:(CLAuthorizationStatus)status;
// KVO magicness
- (void)beginObservingLocationSettings;
- (void)endObservingLocationSettings;
// Analytics

// UIApplicationState observation
- (void)beginObservingUIApplicationState;
// Restart locaiton services if necessary, call single location if necessary
- (void)appWillEnterForeground; 
// Shutdown location services if not enabled. 
- (void)appDidEnterBackground;
// Checks the elapsed time and other variables to decide whether a foreground report is needed
- (BOOL)shouldPerformAutoLocationUpdate;

@end
