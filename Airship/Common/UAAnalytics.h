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
#import <Foundation/Foundation.h>
#import "UAHTTPConnection.h"

@class UAEvent;

// Used for init local size if server didn't response, or server sends bad data

//total size in kilobytes that the event queue is allowed to grow to.
#define X_UA_MAX_TOTAL 5*1024*1024	// local max of 5MB

// total size in kilobytes that a given event post is allowed to send.
#define X_UA_MAX_BATCH 500*1024		// local max of 500kb

// maximum amount of time in seconds that events should queue for
#define X_UA_MAX_WAIT 7*24*3600		// local max of 7 days

// minimum amount of time in seconds that should elapse between event-server posts
#define X_UA_MIN_BATCH_INTERVAL 60	// local min of 60s

extern NSString * const UAAnalyticsOptionsRemoteNotificationKey;
extern NSString * const UAAnalyticsOptionsServerKey;
extern NSString * const UAAnalyticsOptionsLoggingKey;

@interface UAAnalytics : NSObject<UAHTTPConnectionDelegate> {
  @private
    NSString *server;
    NSMutableDictionary *session;

    NSDictionary *notificationUserInfo;

    BOOL wasBackgrounded;
    UAHTTPConnection *connection;

    int x_ua_max_total;
    int x_ua_max_batch;
    int x_ua_max_wait;
    int x_ua_min_batch_interval;
	
	int sendInterval;

    int databaseSize;
    NSTimeInterval oldestEventTime;
    NSDate *lastSendTime;
    NSTimer *reSendTimer;
    
    BOOL analyticsLoggingEnabled;
    
    NSString *packageVersion;
}

@property (retain) NSString *server;
@property (retain, readonly) NSMutableDictionary *session;
@property (assign, readonly) int databaseSize;
@property (assign, readonly) int x_ua_max_total;
@property (assign, readonly) int x_ua_max_batch;
@property (assign, readonly) int x_ua_max_wait;
@property (assign, readonly) int x_ua_min_batch_interval;
@property (assign, nonatomic) int sendInterval;
@property (assign, readonly) NSTimeInterval oldestEventTime;
@property (retain, readonly) NSDate *lastSendTime;

- (id)initWithOptions:(NSDictionary *)options;
- (void)restoreFromDefault;
- (void)saveDefault;

- (void)addEvent:(UAEvent *)event;
- (void)handleNotification:(NSDictionary *)userInfo;

- (void)resetEventsDatabaseStatus;
- (void)sendIfNeeded;

@end
