/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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

#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUtils.h"
#import "UA_SBJSON.h"
#import "UA_Reachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#define kAnalyticsProductionServer @"https://combine.urbanairship.com";

NSString * const UAAnalyticsOptionsRemoteNotificationKey = @"UAAnalyticsOptionsRemoteNotificationKey";
NSString * const UAAnalyticsOptionsServerKey = @"UAAnalyticsOptionsServerKey";

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));
UIKIT_EXTERN NSString* const UIApplicationDidBecomeActiveNotification __attribute__((weak_import));

@implementation UAAnalytics

@synthesize server;
@synthesize session;
@synthesize databaseSize;
@synthesize x_ua_max_total;
@synthesize x_ua_max_batch;
@synthesize x_ua_max_wait;
@synthesize x_ua_min_batch_interval;
@synthesize oldestEvent;
@synthesize lastSendTime;

- (void)refreshSessionWhenNetworkChanged {
    // Caputre connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    NSString* connectionTypeString = @"";
    switch (netStatus)
    {
        case NotReachable:
        {
            connectionTypeString = @"none";//this should never be sent
            break;
        }

        case ReachableViaWWAN:
        {
            connectionTypeString = @"wwan";
            break;
        }
        case ReachableViaWiFi:
        {
            connectionTypeString = @"wifi";
            break;
        }
    }
    [session setValue:connectionTypeString forKey:@"connection_type"];

}

- (void)restoreFromDefault {
    int tmp = [[NSUserDefaults standardUserDefaults] integerForKey:@"X-UA-Max-Total"];
    if (tmp > 0) {
        x_ua_max_total = tmp;
    }
    tmp = [[NSUserDefaults standardUserDefaults] integerForKey:@"X-UA-Max-Batch"];
    if (tmp > 0) {
        x_ua_max_batch = tmp;
    }
    tmp = [[NSUserDefaults standardUserDefaults] integerForKey:@"X-UA-Max-Wait"];
    if (tmp > 0) {
        x_ua_max_wait = tmp;
    }
    tmp = [[NSUserDefaults standardUserDefaults] integerForKey:@"X-UA-Min-Batch-Interval"];
    if (tmp > 0) {
        x_ua_min_batch_interval = tmp;
    }
    NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"X-UA-Last-Send-Time"];
    if (date != nil) {
        RELEASE_SAFELY(lastSendTime);
        lastSendTime = [date retain];
    }

}

- (void)saveDefault {
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_total forKey:@"X-UA-Max-Total"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_batch forKey:@"X-UA-Max-Batch"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_wait forKey:@"X-UA-Max-Wait"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_min_batch_interval forKey:@"X-UA-Min-Batch-Interval"];
    [[NSUserDefaults standardUserDefaults] setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
}


- (void)refreshSessionWhenActive {
    // marking the beginning of a new session
    [session setObject:[UAUtils UUID] forKey:@"session_id"];

    //setup session with push id
    BOOL launchedFromPush = notificationUserInfo != nil;
    NSArray *pushIds = [notificationUserInfo objectForKey:@"_uaid"];
    NSString *pushId = nil;
    if (pushIds.count > 0) {
        pushId = [pushIds objectAtIndex:0];
    }
    NSArray *inboxIds = [notificationUserInfo objectForKey:@"_uamid"];
    NSString *inboxId = nil;
    if (inboxIds.count > 0) {
        inboxId = [inboxIds objectAtIndex:0];
    }
    if (pushId != nil) {
        [session setValue:pushId forKey:@"launched_from_push_id"];
    } else if (inboxId != nil) {
        [session setValue:inboxId forKey:@"launched_from_push_id"];
    } else if (launchedFromPush) {
        [session setValue:@"true" forKey:@"launched_from_push_id"];
    } else {
        [session setValue:[UAUtils UUID] forKey:@"launched_from_push_id"];
    }
    RELEASE_SAFELY(notificationUserInfo);

    // check enabled notification types
    NSMutableArray *notification_types = [NSMutableArray array];
    UIRemoteNotificationType enabledRemoteNotificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    if ((UIRemoteNotificationTypeBadge | enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"badge"];
    }
    if ((UIRemoteNotificationTypeSound | enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"sound"];
    }
    if ((UIRemoteNotificationTypeAlert | enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"alert"];
    }
    [session setObject:notification_types forKey:@"notification_types"];

    NSTimeZone *localtz = [NSTimeZone localTimeZone];
    [session setObject:[NSString stringWithFormat:@"%d", [localtz secondsFromGMT]] forKey:@"time_zone"];
    [session setObject:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];
}

- (void)initSession {
    session = [[NSMutableDictionary alloc] init];

    [self refreshSessionWhenNetworkChanged];
    [self refreshSessionWhenActive];
}

- (void)enterForeground {
    if (wasBackgrounded) {
        wasBackgrounded = NO;

        [self refreshSessionWhenNetworkChanged];
        //update session in case the app lunched from push while sleep in background
        [self refreshSessionWhenActive];

        //add app_foreground event
        [self addEvent:[UAEventAppForeground eventWithContext:nil]];

    }
}

- (void)enterBackground {
    wasBackgrounded = YES;

    // add app_background event
    [self addEvent:[UAEventAppBackground eventWithContext:nil]];
}

- (id)initWithOptions:(NSDictionary *)options {
    if (self = [super init]) {

        //set server to default if not specified in options
        self.server = [options objectForKey:UAAnalyticsOptionsServerKey];
        if (self.server == nil) {
            self.server = kAnalyticsProductionServer;
        }

        connection = nil;

        databaseSize = 0;
        oldestEvent = nil;
        lastSendTime = nil;
        reSendTimer = nil;

        x_ua_max_total = X_UA_MAX_TOTAL;
        x_ua_max_batch = X_UA_MAX_BATCH;
        x_ua_max_wait = X_UA_MAX_WAIT;
        x_ua_min_batch_interval = X_UA_MIN_BATCH_INTERVAL;

        [self restoreFromDefault];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshSessionWhenNetworkChanged)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        IF_IOS4_OR_GREATER(
            if (&UIApplicationDidEnterBackgroundNotification != NULL) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(enterBackground)
                                                             name:UIApplicationDidEnterBackgroundNotification
                                                           object:nil];
            }

            if (&UIApplicationDidBecomeActiveNotification != NULL) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(enterForeground)
                                                             name:UIApplicationDidBecomeActiveNotification
                                                           object:nil];
            }
        );
        wasBackgrounded = NO;
        notificationUserInfo = [[options objectForKey:UAAnalyticsOptionsRemoteNotificationKey] retain];
        [self initSession];
    }
    return self;
}

#pragma mark -
#pragma mark Analytics

- (void)handleNotification:(NSDictionary*)userInfo {
    RELEASE_SAFELY(notificationUserInfo);
    notificationUserInfo = [userInfo retain];
}

- (void)addEvent:(UAEvent*)event {
    UALOG(@"Add event type=%@ time=%@ data=%@", [event getType], event.time, event.data);
    [[UAAnalyticsDBManager shared] addEvent:event withSession:session];
    databaseSize += [event getEstimateSize];
    if (oldestEvent == nil) {
        oldestEvent = [event retain];
    }
    [self sendIfNeeded];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE_SAFELY(notificationUserInfo);
    RELEASE_SAFELY(session);
    RELEASE_SAFELY(connection);
    RELEASE_SAFELY(oldestEvent);
    RELEASE_SAFELY(lastSendTime);
    [reSendTimer invalidate];
    RELEASE_SAFELY(reSendTimer);
    RELEASE_SAFELY(server);

    [super dealloc];
}

#pragma mark -
#pragma mark UAHTTPConnectionDelegate

- (void)requestDidSucceed:(UAHTTPRequest *)request
                 response:(NSHTTPURLResponse *)response
             responseData:(NSData *)responseData {
    UALOG(@"Analytics data sent successfully. Status: %d", [response statusCode]);
    UALOG(@"responseData=%@, length=%d", [responseData description], [responseData length]);

    RELEASE_SAFELY(connection);
    if ([response statusCode] == 200) {
        [[UAAnalyticsDBManager shared] deleteEvents:request.userInfo];
        [self resetEventsDatabaseStatus];
    } else {
        return;
    }

    if ([response allHeaderFields]) {
        int tmp = [[[response allHeaderFields] objectForKey:@"X-UA-Max-Total"] intValue];
        if (tmp > 0) {
            x_ua_max_total = tmp;
        }
        tmp = [[[response allHeaderFields] objectForKey:@"X-UA-Max-Batch"] intValue];
        if (tmp > 0) {
            x_ua_max_batch = tmp;
        }
        tmp = [[[response allHeaderFields] objectForKey:@"X-UA-Max-Wait"] intValue];
        if (tmp > 0) {
            x_ua_max_wait = tmp;
        }
        tmp = [[[response allHeaderFields] objectForKey:@"X-UA-Min-Batch-Interval"] intValue];
        if (tmp > 0) {
            x_ua_min_batch_interval = tmp;
        }
        [self saveDefault];
    }

    //Make sure we send all events if we could send.
    [self sendIfNeeded];
}

- (void)requestDidFail:(UAHTTPRequest *)request {
    UALOG(@"Send analytics data request failed.");
    //TODO: Deal with retry;
    RELEASE_SAFELY(connection);
}

#pragma mark -

- (void)resetEventsDatabaseStatus {
    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:-1];
    NSDictionary *event;
    databaseSize = 0;
    RELEASE_SAFELY(oldestEvent);
    int eventSize;

    for (event in events) {
        if (oldestEvent == nil)
            oldestEvent = [event retain];
        eventSize = [[event objectForKey:@"event_size"] intValue];
        assert(eventSize > 0);
        databaseSize += eventSize;
    }

}


- (void)sendImpl {
    if (self.server == nil || [self.server length] == 0) {
        UALOG("Analytics disabled.");
        return;
    }
    if (connection != nil) {
        UALOG("Analytics sending already in progress now.");
        return;
    }

    NSArray *events = [[UAAnalyticsDBManager shared] getEventsBySize:x_ua_max_batch];
    NSMutableDictionary *event;
    if ([events count] <=0 ) {
        UALOG(@"Warning: there is no events.");
        return;
    }
    NSString *key;

    NSString *urlString = [NSString stringWithFormat:@"%@%@", server, @"/warp9/"];
    UIDevice *device = [UIDevice currentDevice];
    event = [events objectAtIndex:0];
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    [request addRequestHeader:@"X-UA-Library" value:[event objectForKey:@"lib_version"]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-Device-Family" value:device.systemName];
    [request addRequestHeader:@"X-UA-OS-Version" value:[event objectForKey:@"os_version"]];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];
    [request addRequestHeader:@"Content-Type" value: @"application/json"];

    for (event in events) {
        NSMutableDictionary *eventData = nil;//(NSMutableDictionary*)[event objectForKey:@"data"];
        if (eventData == nil) {
            eventData = [[NSMutableDictionary alloc] init];
            [event setObject:eventData forKey:@"data"];
        }

        for (key in [event allKeys]) {
            if ([key isEqualToString:@"type"] || [key isEqualToString:@"time"]
                || [key isEqualToString:@"event_id"] || [key isEqualToString:@"data"]) {
                ;
            } else {
                if ([event objectForKey:key] != nil)
                    [eventData setObject:[event objectForKey:key] forKey:key];
                [event removeObjectForKey:key];
            }
        }
    }

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    [request appendPostData:[[writer stringWithObject:events] dataUsingEncoding:NSUTF8StringEncoding]];
    request.userInfo = events;

    UALOG(@"Sending to server: %@", self.server);
    UALOG(@"Sending analytics headers: %@", [request.headers descriptionWithLocale:nil indent:1]);
    UALOG(@"Sending analytics body: %@", [writer stringWithObject:events]);
    [writer release];

    connection = [[UAHTTPConnection connectionWithRequest:request] retain];
    connection.delegate = self;
    [connection start];
}

- (void)send {
    if (lastSendTime != nil) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:lastSendTime];
        if (interval < x_ua_min_batch_interval) {
            if (reSendTimer == nil) {
                reSendTimer = [[NSTimer scheduledTimerWithTimeInterval:x_ua_min_batch_interval-interval
                                                                target:self
                                                              selector:@selector(timerReSend:)
                                                              userInfo:nil
                                                               repeats:NO] retain];
            }
            return;
        } else if (reSendTimer) {
            // This condition is very hard to appear, depends on the hardware OS timer
            return;
        }
    }

    [self sendImpl];

    RELEASE_SAFELY(lastSendTime);
    lastSendTime = [[NSDate date] retain];
    [self saveDefault];
}

- (void)timerReSend:(NSTimer *)timer {
    [reSendTimer invalidate];
    RELEASE_SAFELY(reSendTimer);
    [self send];
}

- (void)sendIfNeeded {
    //Delete should be before send step, otherwise, we may send some delete events.
    while (databaseSize > x_ua_max_total) {
        [[UAAnalyticsDBManager shared] deleteOldestSession];
        [self resetEventsDatabaseStatus];
    }

    if (databaseSize >= x_ua_max_batch) {
        [self send];
    } else if (oldestEvent != nil) {
        NSTimeInterval timeInterval = [oldestEvent.time doubleValue];
        if (timeInterval <= 0)
            return;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (timeInterval + x_ua_max_wait <= now)
            [self send];
    }

}


@end
