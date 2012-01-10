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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>


typedef enum {
    UALocationManagerUpdating = 0,
    UALocationManagerNotUpdating,
    UALocationManagerNotEnabled,
    UALocationManagerNotAuthorized
} UALocationManagerStatus;

@interface UALocationManager : NSObject <CLLocationManagerDelegate> {
    @private
    CLLocationManager *locationManager_;
    UALocationManagerStatus currentStatus_;
    BOOL backgroundLocationMonitoringEnabled_;
}

@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, assign, readonly) UALocationManagerStatus currentStatus;

/** Enables location monitoring in the background.
 *  If this is not set to YES, location monitoring for Urban Airship
 *  is terminated when the app enters the background
 **/
@property (nonatomic, assign) BOOL backgroundLocationMonitoringEnabled;

// KVO compliant methods to pass settings to CLLocationManager
- (CLLocationAccuracy)desiredAccuracy;
- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy;

- (CLLocationDistance)distanceFilter;
- (void)setDistanceFilter:(CLLocationDistance)distanceFilter;

/** Starts updating the location and reporting to Urban Airship
 *  TODO: Fill this in when update timing is finalized
 **/
- (void)startUpdatingLocation;

/** Stops updating the location. If this method is called while
 *  the automatic location service is enabled, it will terminate that
 *  service. 
 **/
- (void)stopUpdatingLocation;

/** Enabling automatic location updates creates an update event at the
 *  following times:
 *  1. Immediately when called
 *  2. Every time the app returns to the foreground, AND more than 60 seconds
 *     have passed.
 *  Returns:
 *      YES if services are available and service is started
 *      NO if services are unavailable, or unauthorized
 **/
- (BOOL)enableAutomaticStandardLocationUpdates;








@end
