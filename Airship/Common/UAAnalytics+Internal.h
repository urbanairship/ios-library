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

@interface UAAnalytics () {
    NSString *server;
    NSMutableDictionary *session;
    NSDictionary *notificationUserInfo_;
    UAHTTPConnection *connection;
    int x_ua_max_total;
    int x_ua_max_batch;
    int x_ua_max_wait;
    int x_ua_min_batch_interval;	
	int sendInterval;
    int databaseSize;
    NSTimeInterval oldestEventTime;    
    NSDate *lastSendTime_;
    NSDate *lastLocationSendTime;    
    NSTimer *sendTimer_;    
    BOOL analyticsLoggingEnabled;    
    NSString *packageVersion;
    UIBackgroundTaskIdentifier sendBackgroundTask_; 
}

@property (nonatomic, copy) NSString *server;
@property (nonatomic, retain) NSMutableDictionary *session;
@property (nonatomic, assign) NSTimeInterval oldestEventTime;
@property (nonatomic, retain) NSTimer *sendTimer;
@property (nonatomic, assign) UIBackgroundTaskIdentifier sendBackgroundTask;
@property (nonatomic, retain) NSDictionary *notificationUserInfo;

- (void)restoreFromDefault;
- (void)saveDefault;
- (void)resetEventsDatabaseStatus;
- (void)send;
- (void)setupSendTimer:(NSTimeInterval)timeInterval;
- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse*)response;
- (BOOL)shouldSendAnalytics;
- (void)setLastSendTime:(NSDate*)lastSendTime;
@end