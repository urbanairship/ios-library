/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.
 
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

#import "UAAnalytics.h"

//total size in bytes that the event queue is allowed to grow to.
#define kMaxTotalDBSizeBytes (NSUInteger)5*1024*1024 // local max of 5MB
#define kMinTotalDBSizeBytes (NSUInteger)10*1024     // local min of 10KB

// total size in bytes that a given event post is allowed to send.
#define kMaxBatchSizeBytes (NSUInteger)500*1024      // local max of 500KB
#define kMinBatchSizeBytes (NSUInteger)1024          // local min of 1KB

// maximum amount of time in seconds that events should queue for
#define kMaxWaitSeconds (NSTimeInterval)14*24*3600      // local max of 14 days
#define kMinWaitSeconds (NSTimeInterval)7*24*3600       // local min of 7 days

// Batch time modifiers based on priority and application state
#define kHighPriorityBatchWaitSeconds (NSTimeInterval)1          // local priority min of 1s
#define kInitialForegroundBatchWaitSeconds (NSTimeInterval)15    // local priority batch interval of 15s
#define kInitialBackgroundBatchWaitSeconds (NSTimeInterval)5     // local priority batch interval of 5s

// The actual amount of time in seconds that elapse between event-server posts
#define kMinBatchIntervalSeconds (NSTimeInterval)60        // local min of 60s
#define kMaxBatchIntervalSeconds (NSTimeInterval)7*24*3600  // local max of 7 days

// Minimum amount of time between background low priority event sends
#define kMinBackgroundLowPriorityEventSendIntervalSeconds 900 // 900 seconds = 15 minutes

#define kMaxTotalDBSizeUserDefaultsKey @"X-UA-Max-Total"
#define kMaxBatchSizeUserDefaultsKey @"X-UA-Max-Batch"
#define kMaxWaitUserDefaultsKey @"X-UA-Max-Wait"
#define kMinBatchIntervalUserDefaultsKey @"X-UA-Min-Batch-Interval"
#define kUAAnalyticsEnabled @"UAAnalyticsEnabled"
#define kUAMissingSendID @"MISSING_SEND_ID"
#define kUAPushMetadata @"com.urbanairship.metadata"

@class UACustomEvent;
@class UARegionEvent;

@class UAHTTPRequest;
@class UAAnalyticsDBManager;
@class UAScreenTrackingEvent;

NS_ASSUME_NONNULL_BEGIN


/**
 * Analytics delegate.
 */
@protocol UAAnalyticsDelegate <NSObject>
@optional

/**
 * Called when a custom event was added.
 *
 * @param event The added custom event.
 */
-(void)customEventAdded:(UACustomEvent *)event;


/**
 * Called when a region event was added.
 *
 * @param event The added region event.
 */
-(void)regionEventAdded:(UARegionEvent *)event;

/**
 * Called when a screen was tracked. Called when a `trackScreen:` is first called.
 * An event will be added for the screen will be added after the next time
 * `trackScreen:` is called or if the application backgrounds.
 *
 * @param screenName Name of the screen.
 */
-(void)screenTracked:(NSString *)screenName;

@end


@interface UAAnalytics ()

/**
 * Set a delegate that implements the UAAnalyticsDelegate protocol.
 */
@property (nonatomic, weak, nullable) id<UAAnalyticsDelegate> delegate;

/**
 * The conversion send ID.
 */
@property (nonatomic, copy, nullable) NSString *conversionSendID;

/**
 * The conversion push metadata.
 */
@property (nonatomic, copy, nullable) NSString *conversionPushMetadata;

/**
 * The conversion rich push ID.
 */
@property (nonatomic, copy, nullable) NSString *conversionRichPushID;

/**
 * The current session ID.
 */
@property (nonatomic, copy, nullable) NSString *sessionID;

/**
 * The notification as an NSDictionary.
 */
@property (nonatomic, strong, nullable) NSDictionary *notificationUserInfo;

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
 * The UAConfig object containing the configuration values.
 */
@property (nonatomic, strong) UAConfig *config;

/**
 * The data store to save and load any analytics preferences.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The operation queue used for event uplaods.
 */
@property (nonatomic, strong) NSOperationQueue *sendQueue;

/**
 * Timer to schedule event uploads.
 */
@property (nonatomic, strong, nullable) NSTimer *sendTimer;

/**
 * The earliest time to schedule the intial event upload when adding normal
 * priority events.
 */
@property (nonatomic, strong) NSDate *earliestInitialSendTime;

/**
 * YES if the app is in the process of entering the foreground, but is not yet active.
 * This flag is used to delay sending an `app_foreground` event until the app is active
 * and all of the launch/notification data is present.
 */
@property (nonatomic, assign) BOOL isEnteringForeground;

/**
 * The analytics database manager.
 */
@property (nonatomic, strong) UAAnalyticsDBManager *analyticsDBManager;

/**
 * Factory method to create an analytics instance.
 * @param airshipConfig The 'AirshipConfig.plist' file
 * @param dataStore The shared preference data store.
 * @return A new analytics instance.
 */
+ (instancetype)analyticsWithConfig:(UAConfig *)airshipConfig dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Restores any upload event settings from the
 * preference data store.
 */
- (void)restoreSavedUploadEventSettings;

/**
 * Saves any upload event settings from the headers to the
 * preference data store.
 */
- (void)saveUploadEventSettings;

/**
 * Schedule an event upload.
 * @param delay The delay in seconds from now.
 */
- (void)sendWithDelay:(NSTimeInterval)delay;

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
 * The application terminating.
 */
- (void)willTerminate;

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
 * @return Event data as an NSArray or nil if there are no events to upload.
 */
- (nullable NSArray *)prepareEventsForUpload;

/**
 * Checks a event dictionary for expected fields and values.
 * @param event The event as an NSMutableDictionary to validate.
 * @return `YES` if the event is valid, otherwise `NO`.
 */
- (BOOL)isEventValid:(NSMutableDictionary *)event;

/**
 * Checks database size and event count to determine if there are events to send.
 * @return `YES` If there are events to send, `NO` otherwise.
 */
- (BOOL)hasEventsToSend;

/**
 * Called to notify analytics the app was launched from a push notification.
 * @param notification The push notification.
 */
- (void)launchedFromNotification:(NSDictionary *)notification;

/**
 * Determines the location permission for the app.
 * @return The location permission string.
 */
- (NSString *)locationPermission;

/**
* Invalidates send timer to allow deallocation of UAAnalytics.
*/
- (void)stopSends;

/**
 * Time to wait before sending next batch. 
 * @return The time inerval of (minimum batch interval - last send time) or earliestInitialSendTime,
 * whichever is greater.
 */
- (NSTimeInterval)timeToWaitBeforeSendingNextBatch;

/**
 * The current tracked screen.
 */
@property (nonatomic, strong, nullable) NSString *currentScreen;

/**
 * The previous tracked screen.
 */
@property (nonatomic, strong, nullable) NSString *previousScreen;

/**
 * The start time for current tracked screen.
 */
@property (nonatomic, assign) NSTimeInterval startTime;

@end

NS_ASSUME_NONNULL_END
