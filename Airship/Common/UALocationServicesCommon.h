/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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
#import "UALocalStorageDirectory.h"

/** Shared constants and enums for UALocationServices */

///Various keys
#define kUIBackgroundModesKey @"UIBackgroundModes"
#define kUIBackgroundModeLocationKey @"location"
#define kUALocationServiceDefaultPurpose @"Urban Airship Location Service"

typedef enum {
    UALocationProviderNotUpdating = 0,
    UALocationProviderUpdating
} UALocationProviderStatus;

/** Required for building a location provider */
@protocol UALocationProviderProtocol <NSObject>
@required
/// Required location manager for any location services
@property (nonatomic, retain) CLLocationManager *locationManager;
/// Current status of the location provider
@property (nonatomic, assign) UALocationProviderStatus serviceStatus;
/// This is a required parameter on the CLLocationManager and is presented to the user for authentication
@property (nonatomic, copy) NSString *provider;
/// Starts updating location
- (void)startProvidingLocation;
/// Stops providing location updates
- (void)stopProvidingLocation;
@end

/** Delegate methods for Location providers. All are required */
@protocol UALocationProviderDelegate <NSObject>
@required
/** Delegate call for authorization state changes iOS > 4.2 only 
@param locationProvider The location provider
@param locationManager The CLLocationManager object
@param status The new status
 */
- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider 
       withLocationManager:(CLLocationManager*)locationManager 
didChangeAuthorizationStatus:(CLAuthorizationStatus)status;

/** Delegate is called when a UALocationServices object reports an error 
@param locationProvider The location provider
@param locationManager  The CLLocationManager object
@param error The NSError thrown by the locationManager
 */
- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider 
      withLocationManager:(CLLocationManager*)locationManager 
         didFailWithError:(NSError*)error;

/** Delegate is called when a UALocationService gets a callback
from a CLLocationManager with a location that meets accuracy
requirements.
@param locationProvider The location provider
@param locationManager The CLLocationManager object
@param newLocation The new location reported by the provider
@param oldLocation The previous location reported by the provider
 */
- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider
       withLocationManager:(CLLocationManager *)locationManager 
         didUpdateLocation:(CLLocation*)newLocation
              fromLocation:(CLLocation*)oldLocation;

@end

extern NSString *const UALocationServiceAllowedKey;
extern NSString *const UALocationServiceEnabledKey;
extern NSString *const UALocationServicePurposeKey;

typedef NSString UALocationServiceProviderType;
extern UALocationServiceProviderType *const UALocationServiceProviderGPS;
extern UALocationServiceProviderType *const UALocationServiceProviderNETWORK;
extern UALocationServiceProviderType *const UALocationServiceProviderUNKNOWN;

/** Common enums and protocols for location services */
@interface UALocationServicesCommon
@end



