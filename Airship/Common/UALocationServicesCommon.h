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

/** Shared constants and enums for UALocationServices **/

#define kSessionIdKey @"session_id"
#define kLatKey @"lat"
#define kLongKey @"long"
#define kDesiredAccuracyKey @"requested_accuracy"
#define kUpdateTypeKey @"update_type"
#define kProviderKey @"provider"
#define kUpdateDistanceKey @"update_dist"
#define kHorizontalAccuracyKey @"h_accuracy"
#define kVerticalAccuracyKey @"v_accuracy"
#define kForegroundKey @"foreground"

typedef enum {
    UALocationServiceNotUpdating = 0,
    UALocationServiceUpdating
} UALocationManagerServiceActivityStatus;

@protocol UALocationAnalyticsProtocol <NSObject>
@required
- (CLLocationAccuracy)desiredAccuracy;
- (CLLocationDistance)distanceFilter;
@end

@protocol UALocationServicesDelegate <NSObject>
@optional
/** Delegate is called when a UALocationServices object reports an error */
- (void)uaLocationManager:(id)UALocationServiceObject 
          locationManager:(CLLocationManager*)locationManager 
         didFailWithError:(NSError*)error;
@end