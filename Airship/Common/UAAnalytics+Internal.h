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

#import "UAAnalytics.h"

//total size in bytes that the event queue is allowed to grow to.
#define kMaxTotalDBSizeBytes (NSInteger)5*1024*1024 // local max of 5MB
#define kMinTotalDBSizeBytes (NSInteger)10*1024     // local min of 10KB

// total size in bytes that a given event post is allowed to send.
#define kMaxBatchSizeBytes (NSInteger)500*1024      // local max of 500KB
#define kMinBatchSizeBytes (NSInteger)1024          // local min of 1KB

// maximum amount of time in seconds that events should queue for
#define kMaxWaitSeconds (NSInteger)14*24*3600      // local max of 14 days
#define kMinWaitSeconds (NSInteger)7*24*3600       // local min of 7 days

// The actual amount of time in seconds that elapse between event-server posts
#define kMinBatchIntervalSeconds (NSInteger)60        // local min of 60s
#define kMaxBatchIntervalSeconds (NSInteger)7*24*3600  // local max of 7 days

// minimum amount of time between background location events
#define kMinBackgroundLocationIntervalSeconds 900 // 900 seconds = 15 minutes

// Offset time for use when the app init. This is the time between object
// creation and first upload. Subsequent uploads are defined by
// X_UA_MIN_BATCH_INTERVAL
#define UAAnalyticsFirstBatchUploadInterval 15 // time in seconds

#define kMaxTotalDBSizeUserDefaultsKey @"X-UA-Max-Total"
#define kMaxBatchSizeUserDefaultsKey @"X-UA-Max-Batch"
#define kMaxWaitUserDefaultsKey @"X-UA-Max-Wait"
#define kMinBatchIntervalUserDefaultsKey @"X-UA-Min-Batch-Interval"

@class UAEvent;
@class UAHTTPRequest;

@interface UAAnalytics ()

@property (nonatomic, retain) NSMutableDictionary *session;
@property (nonatomic, retain) NSDictionary *notificationUserInfo;
@property (nonatomic, assign) NSInteger maxTotalDBSize;
@property (nonatomic, assign) NSInteger maxBatchSize;
@property (nonatomic, assign) NSInteger maxWait;
@property (nonatomic, assign) NSInteger minBatchInterval;
@property (nonatomic, assign) NSUInteger databaseSize;
@property (nonatomic, assign) NSTimeInterval oldestEventTime;
@property (nonatomic, assign) UIBackgroundTaskIdentifier sendBackgroundTask;
@property (nonatomic, retain) UAConfig *config;
@property (nonatomic, copy) NSString *packageVersion;
@property (nonatomic, retain) NSOperationQueue *queue;
@property (assign) BOOL isSending;

// YES if the app is in the process of entering the foreground, but is not yet active.
// This flag is used to delay sending an `app_foreground` event until the app is active
// and all of the launch/notification data is present.
@property (nonatomic, assign) BOOL isEnteringForeground;


- (void)initSession;

/* Restores any upload event settings from the 
 standardUserDefaults
 */
- (void)restoreSavedUploadEventSettings;

/* Saves any upload event settings from the headers to the 
 standardUserDefaults 
 */
- (void)saveUploadEventSettings;

- (void)resetEventsDatabaseStatus;

/* Sending analytics */
- (void)send;

- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse*)response;

- (BOOL)shouldSendAnalytics;
- (void)setLastSendTime:(NSDate*)lastSendTime;

/* App State */
- (void)enterForeground;
- (void)enterBackground;
- (void)didBecomeActive;
- (void)willResignActive;

/* Network connectivity */
- (void)refreshSessionWhenNetworkChanged;
- (void)refreshSessionWhenActive;

/* Invalidate the background task that will be running
 if the app has been backgrounded after being active. */
- (void)invalidateBackgroundTask;

/* Generate an analytics request with the proper fields */
- (UAHTTPRequest *)analyticsRequest;

/* Clean up event data for sending
 Enforce max batch limits
 Loop through events and discard DB-only items
 format the JSON field as a dictionary
 */
- (NSArray*)prepareEventsForUpload;

/* Removes old events from the database until the 
 size of the database is less then databaseSize
 */
- (void) pruneEvents;

/** Checks a event dictionary for expected fields
 and values */
- (BOOL) isEventValid:(NSMutableDictionary *)event;

@end
