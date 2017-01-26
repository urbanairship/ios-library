/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

/**
 * Location delegate protocol to receive callbacks for location updates.
 */
@protocol UALocationDelegate <NSObject>

NS_ASSUME_NONNULL_BEGIN

@optional

/**
 * Called when location updates started.
 */
- (void)locationUpdatesStarted;

/**
 * Called when location updates stopped. Location updates will stop
 * if the application background and `isBackgroundLocationUpdatesAllowed` is set
 * to NO, if the user disables location, or if location updates are disabled with
 * `locationUpdatesEnabled`.
 */
- (void)locationUpdatesStopped;

/**
 * Called when new location updates are available. The last location will
 * automatically generate a location event.
 */
- (void)receivedLocationUpdates:(NSArray *)locations;

@end

/**
 * Main class for interacting with Urban Airship location. Used to send location
 * updates for the user to Urban Airship.
 */
@interface UALocation : NSObject


/**
 * Flag to enable/disable requesting location authorization when the location service
 * needs to start. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isAutoRequestAuthorizationEnabled) BOOL autoRequestAuthorizationEnabled;

/**
 * Flag to enable/disable location updates. Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isLocationUpdatesEnabled) BOOL locationUpdatesEnabled;

/**
 * Flag to allow/disallow location updates in the background. Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isBackgroundLocationUpdatesAllowed) BOOL backgroundLocationUpdatesAllowed;

/**
 * UALocationDelegate to receive location callbacks.
 */
@property (nonatomic, weak, nullable) id <UALocationDelegate> delegate;

/**
 * Returns the last received location. Can be nil if no location has been received.
 */
@property (nonatomic, readonly, nullable) CLLocation *lastLocation;

NS_ASSUME_NONNULL_END

@end

