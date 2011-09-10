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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUtils.h"
#import "UA_SBJSON.h"
#import "UA_Reachability.h"

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
@synthesize sendInterval;
@synthesize oldestEventTime;
@synthesize lastSendTime;

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[reSendTimer invalidate];
    
	RELEASE_SAFELY(notificationUserInfo);
    RELEASE_SAFELY(session);
    RELEASE_SAFELY(connection);
    RELEASE_SAFELY(lastSendTime);
    RELEASE_SAFELY(reSendTimer);
    RELEASE_SAFELY(server);
	
    [super dealloc];
}

- (void)refreshSessionWhenNetworkChanged {
    
	// Caputre connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    
	NSString* connectionTypeString = @"";
    
	switch (netStatus) {
			
		case UA_NotReachable:
        {
            connectionTypeString = @"none";//this should never be sent
            break;
        }
			
        case UA_ReachableViaWWAN:
        {
            connectionTypeString = @"cell";
            break;
        }
			
		case UA_ReachableViaWiFi:
        {
            connectionTypeString = @"wifi";
            break;
        }
    }
	
    [session setValue:connectionTypeString forKey:@"connection_type"];
	
}

- (void)refreshSessionWhenActive {
	
    // marking the beginning of a new session
    [session setObject:[UAUtils UUID] forKey:@"session_id"];
	
    // setup session with push id
    BOOL launchedFromPush = notificationUserInfo != nil;
    
	NSString *pushId = [notificationUserInfo objectForKey:@"_"];
	
    // set launched-from-push session values for both push and rich push
    if (pushId != nil) {
        [session setValue:pushId forKey:@"launched_from_push_id"];
    } else if (launchedFromPush) {
        //if the server did not send a push ID (likely because the payload did not have room)
        //generate an ID for the server to use
        [session setValue:[UAUtils UUID] forKey:@"launched_from_push_id"];
    } else {
		[session removeObjectForKey:@"launched_from_push_id"];
	}
    
    // Get the rich push ID, which can be sent as a one-element array or a string
    NSString *richPushId = nil;
    NSObject *richPushValue = [notificationUserInfo objectForKey:@"_uamid"];
    if ([richPushValue isKindOfClass:[NSArray class]]) {
        NSArray *richPushIds = (NSArray *)richPushValue;
        if (richPushIds.count > 0) {
            richPushId = [richPushIds objectAtIndex:0];
        }
    } else if ([richPushValue isKindOfClass:[NSString class]]) {
        richPushId = (NSString *)richPushValue;
    }
    
    if (richPushId != nil) {
        [session setValue:richPushId forKey:@"launched_from_rich_push_id"];
    }
    
	RELEASE_SAFELY(notificationUserInfo);
	
    // check enabled notification types
    NSMutableArray *notification_types = [NSMutableArray array];
    UIRemoteNotificationType enabledRemoteNotificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    
	if ((UIRemoteNotificationTypeBadge & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"badge"];
    }
    
    if ((UIRemoteNotificationTypeSound & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"sound"];
    }
    
    if ((UIRemoteNotificationTypeAlert & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"alert"];
    }
    
// Allow the lib to be built in Xcode 4.1 w/ the iOS 5 newsstand type
// The two blocks below are functionally identical, but they're separated
// for clarity. Once we can build against a stable SDK the second option
// should be removed.
#ifdef __IPHONE_5_0
    if ((UIRemoteNotificationTypeNewsstandContentAvailability & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"newsstand"];
    }
#else
    if (((1 << 3) & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"newsstand"];
    }
#endif
    
	[session setObject:notification_types forKey:@"notification_types"];
	
    NSTimeZone *localtz = [NSTimeZone localTimeZone];
    [session setObject:[NSNumber numberWithDouble:[localtz secondsFromGMT]] forKey:@"time_zone"];
    [session setObject:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];
    
    [session setObject:[[UIDevice currentDevice] systemVersion] forKey:@"os_version"];
    [session setObject:[AirshipVersion get] forKey:@"lib_version"];
    [session setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey] forKey:@"package_version"];
}

- (void)initSession {
    session = [[NSMutableDictionary alloc] init];
	
    [self refreshSessionWhenNetworkChanged];
    [self refreshSessionWhenActive];
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
        lastSendTime = nil;
        reSendTimer = nil;
		
        [self resetEventsDatabaseStatus];
        
        x_ua_max_total = X_UA_MAX_TOTAL;
        x_ua_max_batch = X_UA_MAX_BATCH;
        x_ua_max_wait = X_UA_MAX_WAIT;
        x_ua_min_batch_interval = X_UA_MIN_BATCH_INTERVAL;
		
		// Set out starting interval to the X_UA_MIN_BATCH_INTERVAL as the default value
		sendInterval = X_UA_MIN_BATCH_INTERVAL;
		
        [self restoreFromDefault];
		[self saveDefault];//save defaults to store lastSendTime if this was an initial condition
		
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshSessionWhenNetworkChanged)
                                                     name:kUA_ReachabilityChangedNotification
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

    RELEASE_SAFELY(notificationUserInfo);
    [session removeAllObjects];
}

- (void)restoreFromDefault {
	
	// If the key is missing the int will end up being 0, which is what these checks are (not actual limits)
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
	
	self.sendInterval = sendInterval;
    
	NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"X-UA-Last-Send-Time"];
    
	if (date != nil) {
        RELEASE_SAFELY(lastSendTime);
        lastSendTime = [date retain];
    } else {
		lastSendTime = [[NSDate date] retain];
	}
    
    /*
    UALOG(@"X-UA-Max-Total: %d", x_ua_max_total);
    UALOG(@"X-UA-Min-Batch-Interval: %d", x_ua_min_batch_interval);
    UALOG(@"X-UA-Max-Wait: %d", x_ua_max_wait);
    UALOG(@"X-UA-Max-Batch: %d", x_ua_max_batch);
    UALOG(@"X-UA-Last-Send-Time: %@", [lastSendTime description]);
    */
}

- (void)saveDefault {
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_total forKey:@"X-UA-Max-Total"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_batch forKey:@"X-UA-Max-Batch"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_max_wait forKey:@"X-UA-Max-Wait"];
    [[NSUserDefaults standardUserDefaults] setInteger:x_ua_min_batch_interval forKey:@"X-UA-Min-Batch-Interval"];
    [[NSUserDefaults standardUserDefaults] setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
    
    /*
    UALOG(@"Response Headers Saved:");
    UALOG(@"X-UA-Max-Total: %d", x_ua_max_total);
    UALOG(@"X-UA-Min-Batch-Interval: %d", x_ua_min_batch_interval);
    UALOG(@"X-UA-Max-Wait: %d", x_ua_max_wait);
    UALOG(@"X-UA-Max-Batch: %d", x_ua_max_batch);
    */
}

#pragma mark -
#pragma mark Analytics

- (void)handleNotification:(NSDictionary*)userInfo {
    
    BOOL isActive = YES;
IF_IOS4_OR_GREATER(
                   isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
                   )
    
    if (isActive) {
        [self addEvent:[UAEventPushReceived eventWithContext:userInfo]];
    } else {
        RELEASE_SAFELY(notificationUserInfo);
        notificationUserInfo = [userInfo retain];
    }
}

- (void)addEvent:(UAEvent*)event {
    
    UALOG(@"Add event type=%@ time=%@ data=%@", [event getType], event.time, event.data);
    
	[[UAAnalyticsDBManager shared] addEvent:event withSession:session];
    
	databaseSize += [event getEstimatedSize];
    
	if (oldestEventTime == 0) {
        oldestEventTime = [event.time doubleValue];
    }
        
    // Don't try to send if the event indicates the app is losing focus
    if ([[event getType] isEqualToString:@"app_exit"] || [[event getType] isEqualToString:@"app_background"]) {
        return;
    }
    
	[self sendIfNeeded];
}

#pragma mark -
#pragma mark UAHTTPConnectionDelegate

- (void)requestDidSucceed:(UAHTTPRequest *)request
                 response:(NSHTTPURLResponse *)response
             responseData:(NSData *)responseData {
    
    /*
	UALOG(@"Analytics data sent successfully. Status: %d", [response statusCode]);
    UALOG(@"responseData=%@, length=%d", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease], [responseData length]);
    */
     
    RELEASE_SAFELY(connection);
	
    if ([response statusCode] == 200) {
        [[UAAnalyticsDBManager shared] deleteEvents:request.userInfo];
        [self resetEventsDatabaseStatus];
    } 

    //UALOG(@"Response Headers: %@", [[response allHeaderFields] description]);
    
	// We send headers on all response codes, so let's set those values before checking for != 200
    // NOTE: NSURLHTTPResponse converts header names to title case, so use the X-Ua-Header-Name format
    if ([response allHeaderFields]) {
		
        int tmp = [[[response allHeaderFields] objectForKey:@"X-Ua-Max-Total"] intValue] * 1024;//value returned in KB
        
		if (tmp > 0) {
			
			if(tmp >= X_UA_MAX_TOTAL) {
				x_ua_max_total = X_UA_MAX_TOTAL;
			} else {
				x_ua_max_total = tmp;
			}
			
        } else {
			x_ua_max_total = X_UA_MAX_TOTAL;
		}
 
		tmp = [[[response allHeaderFields] objectForKey:@"X-Ua-Max-Batch"] intValue] * 1024;//value return in KB
        
		if (tmp > 0) {
			
			if (tmp >= X_UA_MAX_BATCH) {
				x_ua_max_batch = X_UA_MAX_BATCH;
			} else {
				x_ua_max_batch = tmp;
			}
			
        } else {
			x_ua_max_batch = X_UA_MAX_BATCH;
		}
        
		tmp = [[[response allHeaderFields] objectForKey:@"X-Ua-Max-Wait"] intValue];
        	
		if (tmp >= X_UA_MAX_WAIT) {
			x_ua_max_wait = X_UA_MAX_WAIT;
		} else {
			x_ua_max_wait = tmp;
		}
        
		tmp = [[[response allHeaderFields] objectForKey:@"X-Ua-Min-Batch-Interval"] intValue];
        
		if (tmp <= X_UA_MIN_BATCH_INTERVAL) {
			x_ua_min_batch_interval = X_UA_MIN_BATCH_INTERVAL;
		} else {
			x_ua_min_batch_interval = tmp;
		}
        
		self.sendInterval = sendInterval;
		
		[self saveDefault];
    }
    
	if ([response statusCode] != 200) {
		return;
    } 

    //Make sure we send all events if we could send.
    [self sendIfNeeded];
}

- (void)requestDidFail:(UAHTTPRequest *)request {
    UALOG(@"Send analytics data request failed.");
    RELEASE_SAFELY(connection);
}

#pragma mark - Custom Property Setters

- (void)setSendInterval:(int)newVal {

	if(newVal < x_ua_min_batch_interval) {
		sendInterval = x_ua_min_batch_interval;
	} else if (newVal > x_ua_max_wait) {
		sendInterval = x_ua_max_wait;
	} else {
		sendInterval = newVal;
	}
	
}


#pragma mark - Send Logic

- (void)resetEventsDatabaseStatus {

	databaseSize = [[UAAnalyticsDBManager shared] sizeInBytes];
    
    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:1];
    if ([events count] > 0) {
        NSDictionary *event = [events objectAtIndex:0];
        oldestEventTime = [[event objectForKey:@"time"] doubleValue];
    } else {
        oldestEventTime = 0;
    }
    
    UALOG(@"Database size: %d", databaseSize);
    UALOG(@"Oldest Event: %f", oldestEventTime);

}

- (void)send {
	
    if (self.server == nil || [self.server length] == 0) {
        UALOG("Analytics disabled.");
        return;
    }
    
	if (connection != nil) {
        //UALOG("Analytics sending already in progress now.");
        return;
    }

    int eventCount = [[UAAnalyticsDBManager shared] eventCount];
    if (eventCount == 0) {
        //UALOG(@"Warning: there are no events.");
        return;
    }
    
    int avgEventSize = databaseSize / eventCount;
    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:x_ua_max_batch/avgEventSize];
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", server, @"/warp9/"];
	UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.compressBody = YES;//enable GZIP
    request.HTTPMethod = @"POST";
    
    // Required Items
    [request addRequestHeader:@"X-UA-Device-Family" value:[UIDevice currentDevice].systemName];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];
    [request addRequestHeader:@"X-UA-Package-Name" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey]];
    [request addRequestHeader:@"X-UA-Package-Version" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey]];
    [request addRequestHeader:@"X-UA-Device-ID" value:[UAUtils udidHash]];
    [request addRequestHeader:@"X-UA-App-Key" value:[UAirship shared].appId];
    
    // Optional Items
    [request addRequestHeader:@"X-UA-Lib-Version" value:[AirshipVersion get]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-OS-Version" value:[[UIDevice currentDevice] systemVersion]];
    
    [request addRequestHeader:@"Content-Type" value: @"application/json"];

    NSArray *topLevelKeys = [NSArray arrayWithObjects:@"type", @"time", @"event_id", @"data", nil];

    int actualSize = 0;
    int batchEventCount = 0;
    
    // Clean up event data for sending.
    // Enforce max batch limits
    // Loop through events and discard DB-only items, format the JSON data field
    // as a dictionary
    NSString *key;
    NSMutableDictionary *event;
	
    for (event in events) {
		
        actualSize += [[event objectForKey:@"event_size"] intValue];
		
        if (actualSize <= x_ua_max_batch) {
            batchEventCount++; 
        } else {
            UALOG(@"Met batch limit.");
            break;
        }
        
        // The event data returned by the DB is a binary plist. Deserialize now.
        NSDictionary *eventData = nil;
        NSData *serializedEventData = (NSData *)[event objectForKey:@"data"];
        
        if (serializedEventData) {
            
            NSString *errString = nil;
            
            eventData = (NSDictionary *)[NSPropertyListSerialization
                                         propertyListFromData:serializedEventData
                                         mutabilityOption:NSPropertyListImmutable
                                         format:NULL /* an out param */
                                         errorDescription:&errString];
            if (errString) {
                UALOG("Deserialization Error: %@", errString);
                [errString release];//must be relased by caller per docs
            }
        }
        
        // Always include a data entry, even if it is empty
        if (!eventData) {
            eventData = [[[NSMutableDictionary alloc] init] autorelease];
        }
		
        [event setValue:eventData forKey:@"data"];

        // Remove unused DB values
        for (key in [event allKeys]) {

            if (![topLevelKeys containsObject:key]) {
                [event removeObjectForKey:key];
            }

        }
    }

    if (batchEventCount < [events count]) {
        events = [events subarrayWithRange:NSMakeRange(0, batchEventCount)];
    }
             
    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    writer.humanReadable = NO;//strip whitespace
    [request appendBodyData:[[writer stringWithObject:events] dataUsingEncoding:NSUTF8StringEncoding]];
    request.userInfo = events;

    writer.humanReadable = YES;//turn on formatting for debugging
    
    /*
    UALOG(@"Sending to server: %@", self.server);
    UALOG(@"Sending analytics headers: %@", [request.headers descriptionWithLocale:nil indent:1]);
    UALOG(@"Sending analytics body: %@", [writer stringWithObject:events]);
    */
     
	[writer release];

    connection = [[UAHTTPConnection connectionWithRequest:request] retain];
    connection.delegate = self;
    
	[connection start];
}

- (void)timerReSend:(NSTimer *)timer {
    @synchronized(self) {
		[reSendTimer invalidate];
		RELEASE_SAFELY(reSendTimer);
    }
	
	[self sendIfNeeded];
}

- (void)sendIfNeeded {
    
    IF_IOS4_OR_GREATER(
                       // if the application is not active, do not attempt to send
                       // this will typically be the case for headless newsstant launches
                       if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
                           return;
                       }
    )
    
    //try sending at this interval if no other thresholds
    //have been met
    //NSInteger stdInterval = x_ua_min_batch_interval * 2;
    
    if (databaseSize <= 0) {
        //UALOG(@"Analytics upload not necessary: no events to send.");
        return;
    }
    
	//Delete oldest events first, otherwise, we may send some deleted events.
	while (databaseSize > x_ua_max_total) {
        UALOG(@"Database exceeds max size of %d bytes... Deleting oldest session.", x_ua_max_total);
        [[UAAnalyticsDBManager shared] deleteOldestSession];
        [self resetEventsDatabaseStatus];
    }
    
    // Check for a resend timer before checking the 
    // interval because the timer may be set with an
    // imprecise time
	@synchronized(self) {
		if (reSendTimer != nil) {
			UALOG(@"Send skipped - a reset timer is already running.");
			return;
		}
	}
	
    // Ensure that we are not sending too often.
    // If we're within the minimum interval, set a timer
    // to retry once the minimum interval is up
    //UALOG(@"Send Analytics");
	
	NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:lastSendTime];
	
	if (interval < sendInterval) {
		UALOG(@"Attempted to send too soon. Setting a timer to comply with the min batch interval.");
		
		//The synchronization may be overkill here, but would prevent
		//two timers from running at once, and one leaking
		@synchronized(self) {
			if (reSendTimer == nil) {
				reSendTimer = [[NSTimer scheduledTimerWithTimeInterval:sendInterval-interval
																target:self
															  selector:@selector(timerReSend:)
															  userInfo:nil
															   repeats:NO] retain];
			}
		}
		
		return;
	}

    
    [self send];
    
    RELEASE_SAFELY(lastSendTime);
    lastSendTime = [[NSDate date] retain];
	
    [self saveDefault];//save defaults to store lastSendTime
}

@end
