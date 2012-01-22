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

@interface UALocationServiceManager : NSObject <CLLocationManagerDelegate>{
    id <UALocationService> locationService_;
    id <UALocationServiceDelegate> delegate_;
    UALocationServiceStatus serviceStatus_;
    CLLocation *lastReportedLocation_;
    NSDate *lastLocationAttempt_;
    BOOL backgroundLocationServiceEnabled_;
    BOOL updateLocationAtLaunch_;
}
@property (nonatomic, retain, readonly) id <UALocationService> locationService;
@property (nonatomic, assign, readonly) id <UALocationServiceDelegate> delegate;
@property (nonatomic, assign, readonly) UALocationServiceStatus serviceStatus;
@property (nonatomic, retain, readonly) CLLocation *lastReportedLocation;
@property (nonatomic, retain, readonly) NSDate *lastLocationAttempt;

/** Allow location services to continue in the background */
@property (nonatomic, assign) BOOL backgroundLocationServiceEnabled;

/** Acquire and send a single location when app returns to foreground
 *  This is a convience method for situations were a different 
 *  monitoring service is desired during application runtime, but
 *  events at app start need to be recorded
 */
@property (nonatomic, assign) BOOL updateLocationAtLaunch;

- (id)initWithLocationService:(id<UALocationService>) locationService;
- (BOOL)startLocationServices;
- (void)stopLocationServices;

/** Checks availability of location services through the 
 *  CLLocationManager. Will only return true when 
 *  [CLLocationManager locationServicesEnabled} == YES
 *  [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized
 *  See CLLocationManager documentation for further information
 */
- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices;

@end

