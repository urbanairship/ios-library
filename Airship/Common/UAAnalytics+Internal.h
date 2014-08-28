/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
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
#define kMaxTotalDBSizeBytes (NSUInteger)5*1024*1024 // local max of 5MB
#define kMinTotalDBSizeBytes (NSUInteger)10*1024     // local min of 10KB

// total size in bytes that a given event post is allowed to send.
#define kMaxBatchSizeBytes (NSUInteger)500*1024      // local max of 500KB
#define kMinBatchSizeBytes (NSUInteger)1024          // local min of 1KB

// maximum amount of time in seconds that events should queue for
#define kMaxWaitSeconds (NSUInteger)14*24*3600      // local max of 14 days
#define kMinWaitSeconds (NSUInteger)7*24*3600       // local min of 7 days

// The actual amount of time in seconds that elapse between event-server posts
#define kMinBatchIntervalSeconds (NSUInteger)60        // local min of 60s
#define kMaxBatchIntervalSeconds (NSUInteger)7*24*3600  // local max of 7 days

// Minimum amount of time between background location events.
#define kMinBackgroundLocationIntervalSeconds 900 // 900 seconds = 15 minutes

#define kMaxTotalDBSizeUserDefaultsKey @"X-UA-Max-Total"
#define kMaxBatchSizeUserDefaultsKey @"X-UA-Max-Batch"
#define kMaxWaitUserDefaultsKey @"X-UA-Max-Wait"
#define kMinBatchIntervalUserDefaultsKey @"X-UA-Min-Batch-Interval"

@class UAEvent;
@class UAHTTPRequest;

@interface UAAnalytics ()

/**
 * The conversion send Id.
 */
@property (nonatomic, copy) NSString *conversionSendId;

/**
 * The conversion rich push Id.
 */
@property (nonatomic, copy) NSString *conversionRichPushId;

/**
 * The current session Id.
 */
@property (nonatomic, copy) NSString *sessionId;

/**
 * The notification as an NSDictionary.
 */
@property (nonatomic, strong) NSDictionary *notificationUserInfo;

/**
 * The maximum size in bytes that the event queue is allowed
 * to grow to.
 */
@property (nonatomic, assign) NSUInteger maxTotalDBSize;

/**
 * The maximum size in bytes that a given event post is allowed
 * to send.
 */
@property (nonatomic, assign) NSUInteger maxBatchSize;

/**
 * The maximum amount of time in seconds that events should queue for.
 */
@property (nonatomic, assign) NSUInteger maxWait;

/**
 * The actual amount of time in seconds that elapse between
 * event-server posts.
 */
@property (nonatomic, assign) NSUInteger minBatchInterval;

/**
 * The size of the database.
 */
@property (nonatomic, assign) NSUInteger databaseSize;

/**
 * The oldest event time as an NSTimeInterval.
 */
@property (nonatomic, assign) NSTimeInterval oldestEventTime;


/**
 * The UAConfig object containing the configuration values.
 */
@property (nonatomic, strong) UAConfig *config;


/**
 * The operation queue used for analytics.
 */
@property (nonatomic, strong) NSOperationQueue *queue;

/**
 * YES if analytics upload is in progress.
 */
@property (atomic, assign) BOOL isSending;

/**
 * YES if the app is in the process of entering the foreground, but is not yet active.
 * This flag is used to delay sending an `app_foreground` event until the app is active
 * and all of the launch/notification data is present.
 */
@property (nonatomic, assign) BOOL isEnteringForeground;

/**
 * Restores any upload event settings from the
 * standardUserDefaults.
 */
- (void)restoreSavedUploadEventSettings;

/**
 * Saves any upload event settings from the headers to the
 * standardUserDefaults.
 */
- (void)saveUploadEventSettings;

/**
 * Resets the event's database oldestEventTime.
 */
- (void)resetEventsDatabaseStatus;

/**
 * Sending analytics.
 */
- (void)send;

/**
 * Update analytics parameters with header values from the response.
 * @param response The response as an NSHTTPURLResponse.
 */
- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse*)response;

/**
 * Sets the last send time analytics data was sent successfully.
 * @param lastSendTime The time as an NSDate.
 */
- (void)setLastSendTime:(NSDate *)lastSendTime;

/* App State */

/**
 * The application entering the foreground.
 */
- (void)enterForeground;

/**
 * The application entering the background.
 */
- (void)enterBackground;

/**
 * The application did become active.
 */
- (void)didBecomeActive;

/**
 * Generate an analytics request with the proper fields
 * @return An analytics request.
 */
- (UAHTTPRequest *)analyticsRequest;

/**
 * Prepare the event data for sending. Enforce max batch limits.
 * Loop through events and discard DB-only items, format the
 * JSON data field as a dictionary.
 * @return Event data as an NSArray.
 */
- (NSArray *)prepareEventsForUpload;

/**
 * Removes old events from the database until the
 * size of the database is less then databaseSize
 */
- (void) pruneEvents;

/**
 * Checks a event dictionary for expected fields and values.
 * @param event The event as an NSMutableDictionary to validate.
 * @return 'YES' if the event is valid, otherwise 'NO'.
 */
- (BOOL)isEventValid:(NSMutableDictionary *)event;


/**
 * Called to notify analytics the app was launched from a push notification.
 * @param notification The push notification.
 */
- (void)launchedFromNotification:(NSDictionary *)notification;

@end
