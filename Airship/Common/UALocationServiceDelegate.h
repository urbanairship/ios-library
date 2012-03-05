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

#import <Foundation/Foundation.h>

/** The UALocationServiceDelegate receives 
    location updates from any of the UALocationServices
 */
@class UALocationService;
@protocol UALocationServiceDelegate <NSObject>

///---------------------------------------------------------------------------------------
/// @name UALocationServiceDelegate
///---------------------------------------------------------------------------------------

@optional
/** Updates the delegate when the location service generates an error
 @param service Location service that generated the error
 @param error Error passed from a CLLocationManager
 */
- (void)UALocationService:(UALocationService*)service didFailWithError:(NSError*)error;
/** Updates the delegate when authorization status has changed
 @warning *Important:* Available on iOS 4.2 or greater only
 @param service Location service reporting the change
 @param status  The updated location authorization status
 */
- (void)UALocationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status;
/** Delegate callbacks for updated locations only occur while the app is in the foreground. If you need background location updates
 create a separate CLLocationManager
 @warning *Important:* This call is not made to the delegate when the service is updating in the background
 @param service The service reporting the location update
 @param newLocation The updated location reported by the service
 @param oldLocation The previously reported location
 */
- (void)UALocationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation;
@end
