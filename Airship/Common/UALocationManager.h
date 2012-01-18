/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import "UALocationServicesCommon.h"

@class UALocationUtils;
@interface UALocationManager : NSObject <CLLocationManagerDelegate, UALocationServicesDelegate, UALocationAnalyticsProtocol> {
    @private
    CLLocationManager *locationManager_;
    UALocationManagerServiceActivityStatus standardLocationActivityStatus_;
    UALocationManagerServiceActivityStatus significantChangeActivityStatus_;
    CLLocation *lastReportedLocation_;
    BOOL backgroundLocationMonitoringEnabled_;
    id <UALocationServicesDelegate> delegate_;
}

@property (nonatomic, retain, readonly) CLLocationManager *locationManager;
@property (nonatomic, assign, readonly) UALocationManagerServiceActivityStatus standardLocationActivityStatus;
@property (nonatomic, assign, readonly) UALocationManagerServiceActivityStatus significantChangeActivityStatus;
@property (nonatomic, retain, readonly) CLLocation *lastReportedLocation;

/** These properties are forwarded to the CLLocationManager */
@property (nonatomic, assign) CLLocationAccuracy desiredAccuracy;
@property (nonatomic, assign) CLLocationDistance distanceFilter;
/***************/

/** Enables location monitoring in the background.
 *  If this is not set to YES, location monitoring for Urban Airship
 *  is terminated when the app enters the background
 **/
@property (nonatomic, assign) BOOL backgroundLocationMonitoringEnabled;

/** UALocationServices delegate is called when the location services 
 *  report an error **/
@property (nonatomic, assign, readonly)id <UALocationServicesDelegate> delegate;


- (id)initWithDelegateOrNil:(id<UALocationServicesDelegate>)delegateOrNil;

/** Starts updating the location and reporting to Urban Airship using the
 *  standard location service. This will not continue if the app has been 
 *  backgrounded.
 *  TODO: Fill this in when update timing is finalized
 *  Both [CLLocationManager locationServicesEnabled] and [CLLocationManager authorizationStatus]
 *  are called before location services begin reporting. Consult those methods for more information.
 *  Returns:
 *      YES if service has started
 *      NO if the service cannot start because of CLLocationManager authorization status
 **/
- (BOOL)startStandardLocationUpdates;

/** Stops updating the location with the Standard Location service.  **/
- (void)stopStandardLocationUpdates;

/** Starts the Significant Change location service. If the backgroundLocationMonitoringEnabled_
 *  flag is not set to YES, this service terminates when the app enters the background. 
 *  Both [CLLocationManager locationServicesEnabled] and [CLLocationManager authorizationStatus]
 *  are called before location services begin reporting. Consult those methods for more information.
 *  Returns:
 *      YES if service has started
 *      NO if the service cannot start because of CLLocationManager authorization status
 **/
- (BOOL)startSignificantChangeLocationUpdates;

/** Stops the Significant Change location service **/
- (void)stopSignificantChangeLocationUpdates;

/** Enabling automatic location updates creates an update event at the
 *  following times:
 *  1. Immediately when called
 *  2. Every time the app returns to the foreground, AND more than 60 seconds
 *     have passed.
 *  Returns:
 *      YES if services are available and service is started
 *      NO if services are unavailable, or unauthorized
 *  
 **/
// This is going to be the automatic turn on and forget service
// haven't figured out how it will work yet. 
- (BOOL)enableAutomaticStandardLocationUpdates;

/** Disables the AutomaticStandaredLocationUpdate service */
- (void)disableAutomaticStandardLocationUpdates;

/** Starts the Standard Location service, acquires a single location that meets
 *  accuracy requirements set in this location manager, and uploads it to UA. 
 *
 **/
- (BOOL)acquireSingleLocationAndUpload;

 

@end
