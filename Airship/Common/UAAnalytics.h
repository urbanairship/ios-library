/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

@class UAEvent;
@class UAConfig;

// Used for init local size if server didn't respond, or server sends bad data

//total size in kilobytes that the event queue is allowed to grow to.
#define kMaxTotalDBSize 5*1024*1024 // local max of 5MB
#define kMinTotalDBSize 10*1024     // local min of 10KB


// total size in kilobytes that a given event post is allowed to send.
#define kMaxBatchSize 500*1024		// local max of 500KB
#define kMinBatchSize 1024          // local min of 1KB


// maximum amount of time in seconds that events should queue for
#define kMaxWait 14*24*3600		// local max of 14 days
#define kMinWait 7*24*3600		// local min of 7 days


// The actual amount of time in seconds that elapse between event-server posts
// TODO: Get with the analytics team and rename this header field
#define kMinBatchInterval 60        // local min of 60s
#define kMaxBatchInterval 7*24*3600	// local max of 7 days


// minimum amount of time between background location events
#define X_UA_MIN_BACKGROUND_LOCATION_INTERVAL 900 // 900 seconds = 15 minutes

// Offset time for use when the app init. This is the time between object
// creation and first upload. Subsequent uploads are defined by 
// X_UA_MIN_BATCH_INTERVAL
#define UAAnalyticsFirstBatchUploadInterval 15 // time in seconds

/**
 * The UAAnalytics object provides an interface to the Urban Airship Analytics API.
 */
@interface UAAnalytics : NSObject

@property (nonatomic, retain, readonly) NSMutableDictionary *session;
@property (nonatomic, assign, readonly) NSTimeInterval oldestEventTime;
@property (nonatomic, assign, readonly) UIBackgroundTaskIdentifier sendBackgroundTask;
@property (nonatomic, retain, readonly) NSDictionary *notificationUserInfo;


/**
 * Initializes with the specified airshipConfig file.
 * @param airshipConfig The 'AirshipConfig.plist' file
 */
- (id)initWithConfig:(UAConfig *)airshipConfig;

/**
 * Triggers an analytics event
 * @param event The event to be triggered
 */
- (void)addEvent:(UAEvent *)event;

/**
 * Handle incoming push notifications.
 * @param userInfo The notification as an NSDictionary.
 * @param applicationState The application state at the time the notification was received.
 */
- (void)handleNotification:(NSDictionary*)userInfo inApplicationState:(UIApplicationState)applicationState;

/** Date representing the last attempt to send analytics */
- (NSDate*)lastSendTime;

@end
