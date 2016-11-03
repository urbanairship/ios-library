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

@class UAEvent;
@class UAConfig;
@class UAPreferenceDataStore;
@class UAEventAPIClient;
@class UAEventStore;

/**
 * Event manager handles storing and uploading events to Urban Airship.
 */
@interface UAEventManager : NSObject

// Max database size
#define kMaxTotalDBSizeBytes (NSUInteger)5*1024*1024 // local max of 5MB
#define kMinTotalDBSizeBytes (NSUInteger)10*1024     // local min of 10KB

// Total size in bytes that a given event post is allowed to send.
#define kMaxBatchSizeBytes (NSUInteger)500*1024      // local max of 500KB
#define kMinBatchSizeBytes (NSUInteger)10*1024          // local min of 10KB

// The actual amount of time in seconds that elapse between event-server posts
#define kMinBatchIntervalSeconds (NSTimeInterval)60        // local min of 60s
#define kMaxBatchIntervalSeconds (NSTimeInterval)7*24*3600  // local max of 7 days

// Data store keys
#define kMaxTotalDBSizeUserDefaultsKey @"X-UA-Max-Total"
#define kMaxBatchSizeUserDefaultsKey @"X-UA-Max-Batch"
#define kMaxWaitUserDefaultsKey @"X-UA-Max-Wait"
#define kMinBatchIntervalUserDefaultsKey @"X-UA-Min-Batch-Interval"

/**
 * Date representing the last attempt to send analytics.
 * @return NSDate representing the last attempt to send analytics
 */
@property (nonatomic, strong, readonly) NSDate *lastSendTime;

/**
 * Default factory method.
 *
 * @param config The airship config.
 * @param dataStore The preference data store.
 * @return UAEventManager instance.
 */
+ (instancetype)eventManagerWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method used for testing.
 *
 * @param config The airship config.
 * @param dataStore The preference data store.
 * @param eventStore The event data store.
 * @param client The event api client.
 * @param queue The operation queue.
 * @return UAEventManager instance.
 */
+ (instancetype)eventManagerWithConfig:(UAConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                            eventStore:(UAEventStore *)eventStore
                                client:(UAEventAPIClient *)client
                                 queue:(NSOperationQueue *)queue;


/**
 * Adds an analytic event to be batched and uploaded to Urban Airship.
 *
 * @param event The analytic event.
 * @param sessionID The analytic session ID.
 */
- (void)addEvent:(UAEvent *)event sessionID:(NSString *)sessionID;

/**
 * Deletes all events and cancels any uploads in progress.
 */
- (void)deleteAllEvents;

/**
 * Schedules an analytic upload.
 */
- (void)scheduleUpload;

/**
 * Cancels any scheduled event uploads.
 */
- (void)cancelUpload;

@end
