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
#import <Availability.h>
#import "UALocationServicesCommon.h"
#import "UALocationServiceDelegate.h"


@class UAStandardLocationProvider;
@class UASignificantChangeProvider;
@class UALocationService;

/** The UALocationService class provides an interface to both the location services on 
 device and the Urban Airship API. 
 */
@interface UALocationService : NSObject <UALocationProviderDelegate> {
    
    NSTimeInterval minimumTimeBetweenForegroundUpdates_;
    CLLocationDistance distanceFilter_;
    CLLocationAccuracy desiredAccuracy_;
    CLLocation *lastReportedLocation_;
    NSDate *dateOfLastReport_;
    id <UALocationServiceDelegate> delegate_;
    BOOL automaticLocationOnForegroundEnabled_;
    BOOL backroundLocationServiceEnabled_;
    UAStandardLocationProvider *standardLocationProvider_;
    UASignificantChangeProvider *significantChangeProvider_;
}

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------

/** Minimum time between automatic updates that are tied to app foreground events.
 Default value is 120 seconds
 */
@property (nonatomic, assign) NSTimeInterval minimumTimeBetweenForegroundUpdates;
/// Distance filter that is set for each new location service 
@property (nonatomic, assign) CLLocationDistance distanceFilter;

/// Accuarcy constraints passed to each location service 
@property (nonatomic, assign) CLLocationAccuracy desiredAccuracy;

/// Last location reported to Urban Airship 
@property (nonatomic, retain,readonly) CLLocation *lastReportedLocation;

/// Date of last location event reported 
@property (nonatomic, retain, readonly) NSDate *dateOfLastReport;

/// UALocationServiceDelage for location service callbacks
@property (nonatomic, assign) id <UALocationServiceDelegate> delegate;

/// Starts the GPS (Standard Location) and acquires a single location on every launch
@property (nonatomic, assign) BOOL automaticLocationOnForegroundEnabled;

/// Allows location services to continue in the background 
@property (nonatomic, assign) BOOL backgroundLocationServiceEnabled;

/** 
 On initialization this is read from NSUserDefaults. This controls
 all location services.
 
 - A value of NO means no location services will run
 - A value of YES means location services will run if authorized.
 */
@property (nonatomic, assign) BOOL locationServiceEnabled;

/** Enables or disables all UALocationServices 
On iOS 4.2 or greater this value is NO when CLLocationManager reports
- kCLAuthorizationStatusRestricted  
- kCLAuthorizationStatusDenied
and YES for 
- kCLAuthorizationStatusAuthorized  
- kCLAuthorizationStatusNotDetermined
On iOS 4.2 and earlier this value is NO after an attempt has been made
to start the location service and a delegate callback with a kCLErrorDenied error is 
received. Enabling service again and attempting to restart location services will
prompt the user if the location service permissions have not changed. 
 */
@property (nonatomic, assign) BOOL locationServiceAllowed;

/// Provides GPS location events 
@property (nonatomic, retain, readonly) UAStandardLocationProvider *standardLocationProvider;

/// Status for GPS service 
@property (nonatomic, assign, readonly) UALocationProviderStatus standardLocationServiceStatus;

/// Cell tower location events 
@property (nonatomic, retain, readonly) UASignificantChangeProvider *significantChangeProvider;

/// Status for NETWORK (cell tower) events
@property (nonatomic, assign, readonly) UALocationProviderStatus significantChangeServiceStatus;

/** Status for single location service */
@property (nonatomic, assign, readonly) UALocationProviderStatus singleLocationServiceStatus;

/** Purpose for location services shown to user
 when prompted to allow location services to begin. The default value
 is kUALocationServiceDefaultPurpose listed in UALocaitonServiceCommon.h
 */
@property (nonatomic, copy) NSString *purpose;

///---------------------------------------------------------------------------------------
/// @name Creating the Location Service
///---------------------------------------------------------------------------------------


/** Returns a UALocationService object with the given purpose. The purpose
 string is passed to the UALocationProviders and set on the CLLocationManager. 
 This is displayed to the user when asking for location authorization.
 @param purpose The description that is displayed to the user when prompted for authorization.
 */
- (id)initWithPurpose:(NSString*)purpose;

/** Starts the Standard Location service and 
 sends location data to Urban Airship. This service will continue updating if the location property is 
 declared in the Info.plist. Please see the Location Awareness Programming guide:
 http://developer.apple.com/library/ios/#documentation/UserExperience/Conceptual/LocationAwarenessPG/Introduction/Introduction.html
 for more information. If the standard location service is not setup for background
 use, it will automatically resume once the app is brought back into the foreground.
 This will not start the location service if the app is not enabled and authorized. To force
 location services to start, set the UALocationServicesAllowed property to YES and call this method.
 This will prompt the user for permission if location services have not been started previously,
 or if the user has purposely disabled location services. Given that location services were probably 
 disabled for a reason, this prompt might not be welcomed. 
 */

///---------------------------------------------------------------------------------------
/// @name Starting and Stopping Location Services
///---------------------------------------------------------------------------------------

/** Start the standard location service */
- (void)startReportingLocation;

/** Stops the standard location service */
- (void)stopReportingLocation;

/** Starts the Significant Change location service
 and sends location data to Urban Airship. This service 
 will continue in the background if stopMonitoringSignificantLocationChanges
 is not called before the app enters the background.
 This will not start the location service if the app is not enabled and authorized. To force
 location services to start, set the UALocationServicesAllowed property to YES and call this method.
 This will prompt the user for permission if location services have not been started previously,
 or if the user has purposely disabled location services. Given that location services were probably 
 disabled for a reason, this prompt might not be welcomed.
 **/
- (void)startReportingSignificantLocationChanges;

/** Stops the Significant Change location service */
- (void)stopReportingSignificantLocationChanges;

///---------------------------------------------------------------------------------------
/// @name Analytics
///---------------------------------------------------------------------------------------

/** Creates a UALocationEvent and enques it with the Analytics service
 @param location The location to be sent to the Urban Airship analytics service
 @param provider The provider that generated the location. Data is pulled from the provider for analytics
*/ 
 - (void)sendLocationToAnalytics:(CLLocation*)location fromProvider:(id<UALocationProviderProtocol>)provider;

/** Starts the standard location service long enough to obtain a location an then uploads
 it to Urban Airship.
*/
- (void)reportCurrentLocation;

///---------------------------------------------------------------------------------------
/// @name Location Service Authorization
///---------------------------------------------------------------------------------------


/** Returns YES if location services are enabled and authorized, NO in all other cases
 Only available on iOS 4.2 or greater
 */
- (BOOL)isLocationServiceEnabledAndAuthorized;

@end
