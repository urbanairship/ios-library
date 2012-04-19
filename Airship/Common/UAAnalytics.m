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

#import "UA_SBJSON.h"
#import "UA_Reachability.h"

#import "UAirship.h"
#import "UAUtils.h"
#import "UAAnalyticsDBManager.h"
#import "UAEvent.h"
#import "UALocationEvent.h"
#import "UAUser.h"
// NOTE: Setup a background task in the appDidBackground method, then use
// that background identifier for should send background logic

#define kAnalyticsProductionServer @"https://combine.urbanairship.com";

// analytics-specific logging method
#define UA_ANALYTICS_LOG(fmt, ...) \
do { \
if (logging && analyticsLoggingEnabled) { \
NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
} \
} while(0)

NSString * const UAAnalyticsOptionsRemoteNotificationKey = @"UAAnalyticsOptionsRemoteNotificationKey";
NSString * const UAAnalyticsOptionsServerKey = @"UAAnalyticsOptionsServerKey";
NSString * const UAAnalyticsOptionsLoggingKey = @"UAAnalyticsOptionsLoggingKey";

UAAnalyticsValue * const UAAnalyticsTrueValue = @"true";
UAAnalyticsValue * const UAAnalyticsFalseValue = @"false";

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationWillEnterForegroundNotification __attribute__((weak_import));
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

@interface UAAnalytics()
- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse*)response;
- (BOOL)shouldSendAnalytics;
@end

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
@synthesize sendTimer;

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [sendTimer invalidate];
    RELEASE_SAFELY(notificationUserInfo);
    RELEASE_SAFELY(session);
    RELEASE_SAFELY(connection);
    RELEASE_SAFELY(lastSendTime);
    RELEASE_SAFELY(server);
    RELEASE_SAFELY(lastLocationSendTime);
    
    [super dealloc];
}

- (void)refreshSessionWhenNetworkChanged {
    
    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    NSString *connectionTypeString = @"";
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
    [session setValue:packageVersion forKey:@"package_version"];
    
    // ensure that the app is foregrounded (necessary for Newsstand background invocation)
    BOOL isInForeground = YES;
    IF_IOS4_OR_GREATER(
                       isInForeground = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground);
                       );
    [session setObject:(isInForeground ? @"true" : @"false") forKey:@"foreground"];
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
        analyticsLoggingEnabled = [[options objectForKey:UAAnalyticsOptionsLoggingKey] boolValue];
        analyticsLoggingEnabled = YES;
        UALOG(@"Analytics logging %@enabled", (analyticsLoggingEnabled ? @"" : @"not "));
        
        if (self.server == nil) {
            self.server = kAnalyticsProductionServer;
        }
        
        connection = nil;
        
        databaseSize = 0;
        lastSendTime = nil;
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

            if (&UIApplicationWillEnterForegroundNotification != NULL) {

               [[NSNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(enterForeground)
                                                            name:UIApplicationWillEnterForegroundNotification
                                                          object:nil];
            }

        );
        
        // App inactive/active for incoming calls, notification center, and taskbar 
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        notificationUserInfo = [[options objectForKey:UAAnalyticsOptionsRemoteNotificationKey] retain];
        
        /*
         * This is the Build field in Xcode. If it's not set, use a blank string.
         */
        packageVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey];
        if (packageVersion == nil) {
            packageVersion = @"";
        }
        
        [self initSession];
        NSMethodSignature *sendSignature = [self methodSignatureForSelector:@selector(send)];
        NSInvocation *sendInvocation = [NSInvocation invocationWithMethodSignature:sendSignature];
        // In Objective C, you don't retain timer, timer retains you
        self.sendTimer = [NSTimer timerWithTimeInterval:5.0 invocation:sendInvocation repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.sendTimer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)enterForeground {
    UA_ANALYTICS_LOG(@"Enter Foreground.");
    [self refreshSessionWhenNetworkChanged];
    //update session in case the app lunched from push while sleep in background
    [self refreshSessionWhenActive];
    
    //add app_foreground event
    [self addEvent:[UAEventAppForeground eventWithContext:nil]];
}

- (void)enterBackground {
    UA_ANALYTICS_LOG(@"Enter Background.");
    // add app_background event
    [self addEvent:[UAEventAppBackground eventWithContext:nil]];
    //TODO: clearing the session could cause an exit event to have an empty payload and it will be dropped - do we care?
    RELEASE_SAFELY(notificationUserInfo);
    [session removeAllObjects];
    //Set a blank session_id for app_exit events
    [session setValue:@"" forKey:@"session_id"];
}

- (void)didBecomeActive {
    UA_ANALYTICS_LOG(@"Application did become active.");    
    //add activity_started / AppActive event
    [self addEvent:[UAEventAppActive eventWithContext:nil]];
}

- (void)willResignActive {
    UA_ANALYTICS_LOG(@"Application will resign active.");    
    //add activity_stopped / AppInactive event
    [self addEvent:[UAEventAppInactive eventWithContext:nil]];
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

// TODO: This actually clobbers values in NSUserDefaults if they have been set.
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

- (void)addEvent:(UAEvent *)event {
    
    UA_ANALYTICS_LOG(@"Add event type=%@ time=%@ data=%@", [event getType], event.time, event.data);
    
    [[UAAnalyticsDBManager shared] addEvent:event withSession:session];
    
    databaseSize += [event getEstimatedSize];
    
    if (oldestEventTime == 0) {
        oldestEventTime = [event.time doubleValue];
    }

    // Don't try to send if the event indicates the app is losing focus
    if ([[event getType] isEqualToString:@"app_exit"] || [[event getType] isEqualToString:@"app_background"]) {
        return;
    }

    // if iOS 3.x, assume active
    BOOL active = YES;
    IF_IOS4_OR_GREATER(
        active = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    );

    // Don't send app init while in the background
    if (!active && [[event getType] isEqualToString:@"app_init"]) {
        return;
    }

    // Do not send locations in the background too often
    if ([[event getType] isEqualToString:locationEventAnalyticsType]) {
        
        // Initialize to sometime really long ago
        if (!lastLocationSendTime) {
            lastLocationSendTime = [[NSDate distantPast] retain];
        }
        
        NSTimeInterval timeSinceLastLocation = [[NSDate date] timeIntervalSinceDate:lastLocationSendTime];
        if (!active && timeSinceLastLocation < 15 * 60/* fifteen minutes */) {
            return;
        } else {
            RELEASE_SAFELY(lastLocationSendTime);
            lastLocationSendTime = [[NSDate date] retain];
        }
    }

    [self send];
}

#pragma mark -
#pragma mark UAHTTPConnectionDelegate

- (void)requestDidSucceed:(UAHTTPRequest *)request
                 response:(NSHTTPURLResponse *)response
             responseData:(NSData *)responseData {

    UALOG(@"Analytics data sent successfully. Status: %d", [response statusCode]);
    UALOG(@"responseData=%@, length=%d", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease], [responseData length]);
     
    RELEASE_SAFELY(connection);
    if ([response statusCode] == 200) {
        [[UAAnalyticsDBManager shared] deleteEvents:request.userInfo];
        [self resetEventsDatabaseStatus];
    } 
    // Update analytics settings with new header values
    [self updateAnalyticsParametersWithHeaderValues:response];
    
    if ([response statusCode] != 200) {
        UA_ANALYTICS_LOG(@"Send analytics data request failed: %d", [response statusCode]);
        return;
    } 
    //TODO: make a catch to send again if more events have come through
}


// We send headers on all response codes, so let's set those values before checking for != 200
// NOTE: NSURLHTTPResponse converts header names to title case, so use the X-Ua-Header-Name format
- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse*)response {
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
        //TODO: setup a last send time here
    }
}

- (void)requestDidFail:(UAHTTPRequest *)request {
    UA_ANALYTICS_LOG(@"Send analytics data request failed.");
    RELEASE_SAFELY(connection);
    // Setup a last send time here, maybe
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
    UA_ANALYTICS_LOG(@"Database size: %d", databaseSize);
    UA_ANALYTICS_LOG(@"Oldest Event: %f", oldestEventTime);
}

- (BOOL)shouldSendAnalytics {
    if (self.server == nil || [self.server length] == 0) {
        UA_ANALYTICS_LOG("Analytics disabled.");
        return NO;
    }
    if (connection != nil) {
        UA_ANALYTICS_LOG(@"Analytics upload in progress");
        return NO;
    }    
    int eventCount = [[UAAnalyticsDBManager shared] eventCount];
    if (eventCount == 0) {
        UA_ANALYTICS_LOG(@"No analytics events to upload");
        return NO;
    }   
    if (databaseSize <= 0) {
        UA_ANALYTICS_LOG(@"Analytics database size is zero, no analytics sent");
        return NO;
    }

    return YES;
}

- (UAHTTPRequest*)analyticsRequest {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", server, @"/warp9/"];
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.compressBody = YES;//enable GZIP
    request.HTTPMethod = @"POST";
    // Required Items
    [request addRequestHeader:@"X-UA-Device-Family" value:[UIDevice currentDevice].systemName];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];
    [request addRequestHeader:@"X-UA-Package-Name" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey]];
    [request addRequestHeader:@"X-UA-Package-Version" value:packageVersion];
    [request addRequestHeader:@"X-UA-ID" value:[UAUtils deviceID]];
    [request addRequestHeader:@"X-UA-User-ID" value:[UAUser defaultUser].username];
    [request addRequestHeader:@"X-UA-App-Key" value:[UAirship shared].appId];
    // Optional Items
    [request addRequestHeader:@"X-UA-Lib-Version" value:[AirshipVersion get]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-OS-Version" value:[[UIDevice currentDevice] systemVersion]];
    [request addRequestHeader:@"Content-Type" value: @"application/json"];
    return request;
}

// Clean up event data for sending.
// Enforce max batch limits
// Loop through events and discard DB-only items, format the JSON data field
// as a dictionary
- (NSArray*) prepareEventsForUpload {
    //Delete older events until upload size threshold is met
    while (databaseSize > x_ua_max_total) {
        UA_ANALYTICS_LOG(@"Database exceeds max size of %d bytes... Deleting oldest session.", x_ua_max_total);
        [[UAAnalyticsDBManager shared] deleteOldestSession];
        [self resetEventsDatabaseStatus];
    }
    int eventCount = [[UAAnalyticsDBManager shared] eventCount];
    int avgEventSize = databaseSize / eventCount;
    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:x_ua_max_batch/avgEventSize];
    NSArray *topLevelKeys = [NSArray arrayWithObjects:@"type", @"time", @"event_id", @"data", nil];
    int actualSize = 0;
    int batchEventCount = 0;
    NSString *key;
    NSMutableDictionary *event;
    for (event in events) {
        actualSize += [[event objectForKey:@"event_size"] intValue];
        if (actualSize <= x_ua_max_batch) {
            batchEventCount++; 
        } else {
            UA_ANALYTICS_LOG(@"Met batch limit.");
            break;
        }
        // The event data returned by the DB is a binary plist. Deserialize now.
        NSMutableDictionary *eventData = nil;
        NSData *serializedEventData = (NSData *)[event objectForKey:@"data"];
        if (serializedEventData) {
            NSString *errString = nil;
            eventData = (NSMutableDictionary *)[NSPropertyListSerialization
                                                propertyListFromData:serializedEventData
                                                mutabilityOption:kCFPropertyListMutableContainersAndLeaves
                                                format:NULL /* an out param */
                                                errorDescription:&errString];
            if (errString) {
                UA_ANALYTICS_LOG("Deserialization Error: %@", errString);
                [errString release];//must be relased by caller per docs
            }
        }
        // Always include a data entry, even if it is empty
        if (!eventData) {
            eventData = [[[NSMutableDictionary alloc] init] autorelease];
        }
        [eventData setValue:[event objectForKey:@"session_id"] forKey:@"session_id"];
        [event setValue:eventData forKey:@"data"];
        // Remove unused DB values
        for (key in [event allKeys]) {
            if (![topLevelKeys containsObject:key]) {
                [event removeObjectForKey:key];
            }
        }//for(key
    }//for(event
    if (batchEventCount < [events count]) {
        events = [events subarrayWithRange:NSMakeRange(0, batchEventCount)];
    }
    return events;
}

- (void)send {
    if ([self shouldSendAnalytics] == NO) {
        return;
    }
    UAHTTPRequest *request = [self analyticsRequest];
    NSArray* events = [self prepareEventsForUpload];
    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    writer.humanReadable = NO;//strip whitespace
    [request appendBodyData:[[writer stringWithObject:events] dataUsingEncoding:NSUTF8StringEncoding]];
    request.userInfo = events;
    writer.humanReadable = YES;//turn on formatting for debugging
    UA_ANALYTICS_LOG(@"Sending to server: %@", self.server);
    UA_ANALYTICS_LOG(@"Sending analytics headers: %@", [request.headers descriptionWithLocale:nil indent:1]);
    UA_ANALYTICS_LOG(@"Sending analytics body: %@", [writer stringWithObject:events]);
    [writer release];
    connection = [[UAHTTPConnection connectionWithRequest:request] retain];
    connection.delegate = self;
    [connection start];
}

@end
