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

#import "UAAnalytics+Internal.h"

#import "UA_Reachability.h"

#import "UAirship.h"
#import "UAUtils.h"
#import "UAAnalyticsDBManager.h"
#import "UAEvent.h"
#import "UALocationEvent.h"
#import "UAUser.h"
#import "UAConfig.h"
#import "UAHTTPConnectionOperation.h"
#import "UADelayOperation.h"
#import "UAInboxUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush.h"

typedef void (^UAAnalyticsUploadCompletionBlock)(void);

@implementation UAAnalytics

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.queue cancelAllOperations];
    
    
}

- (id)initWithConfig:(UAConfig *)airshipConfig {
    self = [super init];
    if (self) {
        //set server to default if not specified in options
        self.config = airshipConfig;
        
        [self resetEventsDatabaseStatus];

        [self restoreSavedUploadEventSettings];
        [self saveUploadEventSettings];//save defaults to store lastSendTime if this was an initial condition
        
        // Register for interface-change notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshSessionWhenNetworkChanged)
                                                     name:kUA_ReachabilityChangedNotification
                                                   object:nil];
        
        // Register for background notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        // Register for foreground notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        // App inactive/active for incoming calls, notification center, and taskbar 
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        // This is the Build field in Xcode. If it's not set, use a blank string.
        self.packageVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey] ?: @"";
        
        [self initSession];
        self.sendBackgroundTask = UIBackgroundTaskInvalid;

        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    
    return self;
}

- (void) delayNextSend:(NSTimeInterval)time {
    //call send after waiting for the first batch upload interval
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:UAAnalyticsFirstBatchUploadInterval];
    delayOperation.completionBlock = ^{
        [self send];
    };

    [self.queue addOperation:delayOperation];
}

- (void)initSession {
    self.session = [NSMutableDictionary dictionary];
    [self refreshSessionWhenNetworkChanged];
    [self refreshSessionWhenActive];
}

#pragma mark -
#pragma mark Network Changes

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
    [self.session setValue:connectionTypeString forKey:@"connection_type"];
}

- (void)refreshSessionWhenActive {
    
    // marking the beginning of a new session
    [self.session setObject:[UAUtils UUID] forKey:@"session_id"];
    
    // setup session with push id
    BOOL launchedFromPush = self.notificationUserInfo != nil;
    
    NSString *pushId = [self.notificationUserInfo objectForKey:@"_"];
    
    // set launched-from-push session values for both push and rich push
    if (pushId != nil) {
        [self.session setValue:pushId forKey:@"launched_from_push_id"];
    } else if (launchedFromPush) {
        //if the server did not send a push ID (likely because the payload did not have room)
        //generate an ID for the server to use
        [self.session setValue:[UAUtils UUID] forKey:@"launched_from_push_id"];
    } else {
        [self.session removeObjectForKey:@"launched_from_push_id"];
    }

    [UAInboxUtils getRichPushMessageIDFromNotification:self.notificationUserInfo withAction:^(NSString *richPushId){
        [self.session setValue:richPushId forKey:@"launched_from_rich_push_id"];
    }];
    
    self.notificationUserInfo = nil;
    
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

    if ((UIRemoteNotificationTypeNewsstandContentAvailability & enabledRemoteNotificationTypes) > 0) {
        [notification_types addObject:@"newsstand"];
    }
    
    [self.session setObject:notification_types forKey:@"notification_types"];
    
    NSTimeZone *localtz = [NSTimeZone defaultTimeZone];
    [self.session setValue:[NSNumber numberWithDouble:[localtz secondsFromGMT]] forKey:@"time_zone"];
    [self.session setValue:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];

    [self.session setValue:[[UIDevice currentDevice] systemVersion] forKey:@"os_version"];
    [self.session setValue:[UAirshipVersion get] forKey:@"lib_version"];
    [self.session setValue:self.packageVersion forKey:@"package_version"];
    
    // ensure that the app is foregrounded (necessary for Newsstand background invocation
    BOOL isInForeground = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground);
    [self.session setValue:(isInForeground ? @"true" : @"false") forKey:@"foreground"];
}

#pragma mark -
#pragma mark Application State

- (void)enterForeground {
    UA_LTRACE(@"Enter Foreground.");

    [self invalidateBackgroundTask];
    // do not send the foreground event yet, as we are not actually in the foreground
    // (we are merely in the process of foregorunding)
    // set this flag so that the even will be sent as soon as the app is active.
    self.isEnteringForeground = YES;
}

- (void)enterBackground {
    UA_LTRACE(@"Enter Background.");

    // add app_background event
    [self addEvent:[UAEventAppBackground eventWithContext:nil]];
    
    //Set a blank session_id for app_exit events
    [self.session removeAllObjects];
    [self.session setValue:@"" forKey:@"session_id"];

    self.notificationUserInfo = nil;

    // Only place where a background task is created
    self.sendBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.queue cancelAllOperations];
        [self invalidateBackgroundTask];
    }];

    [self send];
}

- (void)invalidateBackgroundTask {
    if (self.sendBackgroundTask != UIBackgroundTaskInvalid) {
        UA_LTRACE(@"Ending analytics background task %lu", (unsigned long)self.sendBackgroundTask);
        
        [[UIApplication sharedApplication] endBackgroundTask:self.sendBackgroundTask];
        self.sendBackgroundTask = UIBackgroundTaskInvalid;
    }
}

- (void)didBecomeActive {
    UA_LTRACE(@"Application did become active.");
    
    // If this is the first 'inactive->active' transition in this session,
    // send 
    if (self.isEnteringForeground) {
        self.isEnteringForeground = NO;
        
        //update the network connection_type value
        [self refreshSessionWhenNetworkChanged];

        //update session in case the app lunched from push while sleep in background
        [self refreshSessionWhenActive];

        //add app_foreground event
        [self addEvent:[UAEventAppForeground eventWithContext:nil]];
    }
    
    //add activity_started / AppActive event
    [self addEvent:[UAEventAppActive eventWithContext:nil]];
}

- (void)willResignActive {
    UA_LTRACE(@"Application will resign active.");
    
    //add activity_stopped / AppInactive event
    [self addEvent:[UAEventAppInactive eventWithContext:nil]];
}

#pragma mark -
#pragma mark NSUserDefaults

- (NSDate*)lastSendTime {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"X-UA-Last-Send-Time"] ?: [NSDate distantPast];
}

- (void)setLastSendTime:(NSDate *)lastSendTime {
    if (lastSendTime) {
        [[NSUserDefaults standardUserDefaults] setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
    }
}

- (void)restoreSavedUploadEventSettings {
    // If the key is missing the int will end up being 0 and the values will clamp to there lower end.
    self.maxTotalDBSize = [[NSUserDefaults standardUserDefaults] integerForKey:kMaxTotalDBSizeUserDefaultsKey];
    self.maxBatchSize = [[NSUserDefaults standardUserDefaults] integerForKey:kMaxBatchSizeUserDefaultsKey];
    self.maxWait = [[NSUserDefaults standardUserDefaults] integerForKey:kMaxWaitUserDefaultsKey];
    self.minBatchInterval = [[NSUserDefaults standardUserDefaults] integerForKey:kMinBatchIntervalUserDefaultsKey];
}

- (void)saveUploadEventSettings {
    [[NSUserDefaults standardUserDefaults] setInteger:self.maxTotalDBSize forKey:kMaxTotalDBSizeUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:self.maxBatchSize forKey:kMaxBatchSizeUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:self.maxWait forKey:kMaxWaitUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:self.minBatchInterval forKey:kMinBatchIntervalUserDefaultsKey];
}

#pragma mark -
#pragma mark Analytics

- (void)handleNotification:(NSDictionary*)userInfo inApplicationState:(UIApplicationState)applicationState {
    switch (applicationState) {
        case UIApplicationStateActive:
            [self addEvent:[UAEventPushReceived eventWithContext:userInfo]];
            break;
        case UIApplicationStateInactive:
            self.notificationUserInfo = userInfo;
            break;
        case UIApplicationStateBackground:
            break;
    }
}

- (void)addEvent:(UAEvent *)event {
    if (self.config.analyticsEnabled) {
        UA_LTRACE(@"Add event type=%@ time=%@ data=%@", [event getType], event.time, event.data);

        [[UAAnalyticsDBManager shared] addEvent:event withSession:self.session];    
        self.databaseSize += [event getEstimatedSize];
        if (self.oldestEventTime == 0) {
            self.oldestEventTime = [event.time doubleValue];
        }
        
        // If the app is in the background without a background task id, then this is a location
        // event, and we should attempt to send. 
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        BOOL isLocation = [event isKindOfClass:[UALocationEvent class]];
        if (appState == UIApplicationStateActive ||
            (self.sendBackgroundTask == UIBackgroundTaskInvalid && appState == UIApplicationStateBackground && isLocation)) {
            [self send];
        }
    }
}

// We send headers on all response codes, so let's set those values before checking for != 200
// NOTE: NSURLHTTPResponse converts header names to title case, so use the X-Ua-Header-Name format
- (void)updateAnalyticsParametersWithHeaderValues:(NSHTTPURLResponse *)response {
    if (![response allHeaderFields]) {
        return;
    }

    id maxTotalValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Total"];
    if (maxTotalValue) {
        self.maxTotalDBSize = [maxTotalValue integerValue] * 1024; //value returned in KB;
    }

    id maxBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Batch"];
    if (maxBatchValue) {
        self.maxBatchSize = [maxBatchValue integerValue] * 1024; //value return in KB
    }

    id maxWaitValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Wait"];
    if (maxWaitValue) {
        self.maxWait = [maxWaitValue integerValue];
    }

    id minBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Min-Batch-Interval"];
    if (minBatchValue) {
        self.minBatchInterval = [minBatchValue integerValue];
    }

    [self saveUploadEventSettings];
}

#pragma mark - 
#pragma mark Custom Property Setters
- (void)setMaxTotalDBSize:(NSInteger)maxTotalDBSize {
    if (maxTotalDBSize < kMinTotalDBSizeBytes) {
        _maxTotalDBSize = kMinTotalDBSizeBytes;
    }else if (maxTotalDBSize > kMaxTotalDBSizeBytes) {
        _maxTotalDBSize = kMaxTotalDBSizeBytes;
    } else {
        _maxTotalDBSize = maxTotalDBSize;
    }
}

- (void)setMaxBatchSize:(NSInteger)maxBatchSize {
    if (maxBatchSize < kMinBatchSizeBytes) {
        _maxBatchSize = kMinBatchSizeBytes;
    }else if (maxBatchSize > kMaxBatchSizeBytes) {
        _maxBatchSize = kMaxBatchSizeBytes;
    } else {
        _maxBatchSize = maxBatchSize;
    }
}

- (void)setMaxWait:(NSInteger)maxWait {
    if (maxWait < kMinWaitSeconds) {
        _maxWait = kMinWaitSeconds;
    }else if (maxWait > kMaxWaitSeconds) {
        _maxWait = kMaxWaitSeconds;
    } else {
        _maxWait = maxWait;
    }
}

- (void)setMinBatchInterval:(NSInteger)minBatchInterval {
    if (minBatchInterval < kMinBatchIntervalSeconds) {
        _minBatchInterval = kMinBatchIntervalSeconds;
    }else if (minBatchInterval > kMaxBatchIntervalSeconds) {
        _minBatchInterval = kMaxBatchIntervalSeconds;
    } else {
        _minBatchInterval = minBatchInterval;
    }
}

#pragma mark -
#pragma mark Send Logic

- (void)resetEventsDatabaseStatus {
    self.databaseSize = [[UAAnalyticsDBManager shared] sizeInBytes];

    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:1];
    if ([events count] > 0) {
        NSDictionary *event = [events objectAtIndex:0];
        self.oldestEventTime = [[event objectForKey:@"time"] doubleValue];
    } else {
        self.oldestEventTime = 0;
    }

    UA_LTRACE(@"Database size: %ld", (long)self.databaseSize);
    UA_LTRACE(@"Oldest Event: %f", self.oldestEventTime);
}

- (BOOL)hasEventsToSend {
    return self.databaseSize > 0 && [[UAAnalyticsDBManager shared] eventCount] > 0;
}

- (BOOL)shouldSendAnalytics {
    if (!self.config.analyticsEnabled) {
        UA_LTRACE("Analytics disabled.");
        return NO;
    }

    if (![self hasEventsToSend]) {
        UA_LTRACE(@"No analytics events to upload.");
        return NO;
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        // If the app is in the background and there is a valid background task to upload events
        if (self.sendBackgroundTask != UIBackgroundTaskInvalid) {
            return YES;
        } else {
            // There is no background task, and the app is in the background, it is likely that
            // this is a location related event and we should only send every 15 minutes
            NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
            return timeSinceLastSend > kMinBackgroundLocationIntervalSeconds;
        }
    }
    
    return YES;
}

- (UAHTTPRequest*)analyticsRequest {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.analyticsURL, @"/warp9/"];
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.compressBody = YES;//enable GZIP
    request.HTTPMethod = @"POST";
    
    // Required Items
    [request addRequestHeader:@"X-UA-Device-Family" value:[UIDevice currentDevice].systemName];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];
    [request addRequestHeader:@"X-UA-Package-Name" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey]];
    [request addRequestHeader:@"X-UA-Package-Version" value:self.packageVersion];
    [request addRequestHeader:@"X-UA-ID" value:[UAUtils deviceID]];
    [request addRequestHeader:@"X-UA-User-ID" value:[UAUser defaultUser].username];
    [request addRequestHeader:@"X-UA-App-Key" value:[UAirship shared].config.appKey];
    
    // Optional Items
    [request addRequestHeader:@"X-UA-Lib-Version" value:[UAirshipVersion get]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-OS-Version" value:[[UIDevice currentDevice] systemVersion]];
    [request addRequestHeader:@"Content-Type" value: @"application/json"];
    [request addRequestHeader:@"X-UA-Timezone" value:[[NSTimeZone defaultTimeZone] name]];
    [request addRequestHeader:@"X-UA-Locale-Language" value:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]];
    [request addRequestHeader:@"X-UA-Locale-Country" value:[[NSLocale currentLocale] objectForKey: NSLocaleCountryCode]];
    [request addRequestHeader:@"X-UA-Locale-Variant" value:[[NSLocale currentLocale] objectForKey: NSLocaleVariantCode]];
    [request addRequestHeader:@"X-UA-Push-Address" value:[UAPush shared].deviceToken];

    return request;
}

- (void)pruneEvents {
    // Delete older events until the database size is met
    while (self.databaseSize > self.maxTotalDBSize) {
        UA_LTRACE(@"Database exceeds max size of %ld bytes... Deleting oldest session.", (long)self.maxTotalDBSize);
        [[UAAnalyticsDBManager shared] deleteOldestSession];
        [self resetEventsDatabaseStatus];
    }
}

- (BOOL) isEventValid:(NSMutableDictionary *)event {
    return [[event objectForKey:@"event_size"]  respondsToSelector:NSSelectorFromString(@"intValue")] &&
            [[event objectForKey:@"data"]       isKindOfClass:[NSData class]] &&
            [[event objectForKey:@"session_id"] isKindOfClass:[NSString class]] &&
            [[event objectForKey:@"type"]       isKindOfClass:[NSString class]] &&
            [[event objectForKey:@"time"]       isKindOfClass:[NSString class]] &&
            [[event objectForKey:@"event_id"]    isKindOfClass:[NSString class]];
}

// Clean up event data for sending.
// Enforce max batch limits
// Loop through events and discard DB-only items, format the JSON data field
// as a dictionary
- (NSArray*)prepareEventsForUpload {
    
    [self pruneEvents];

    if (![self hasEventsToSend]) {
        return nil;
    }

    NSUInteger avgEventSize = self.databaseSize / [[UAAnalyticsDBManager shared] eventCount];
    int actualSize = 0;
    int batchEventCount = 0;
    
    NSArray *events = [[UAAnalyticsDBManager shared] getEvents:self.maxBatchSize/avgEventSize];
    NSArray *topLevelKeys = @[@"type", @"time", @"event_id", @"data"];

    for (NSMutableDictionary *event in events) {
        
        if (![self isEventValid:event]) {
            UA_LERR("Detected invalid event due to possible database corruption. Recreating database");
            [[UAAnalyticsDBManager shared] resetDB];
            return nil;
        }

        actualSize += [[event objectForKey:@"event_size"] intValue];
        
        if (actualSize <= self.maxBatchSize) {
            batchEventCount++; 
        } else {
            UA_LTRACE(@"Met batch limit.");
            break;
        }
        
        // The event data returned by the DB is a binary plist. Deserialize now.
        NSMutableDictionary *eventData = nil;
        NSData *serializedEventData = (NSData *)[event objectForKey:@"data"];
        
        if (serializedEventData) {
            NSString *errString = nil;
            eventData = (NSMutableDictionary *)[NSPropertyListSerialization
                                                propertyListFromData:serializedEventData
                                                mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                format:NULL /* an out param */
                                                errorDescription:&errString];
            
            if (errString) {
                UA_LTRACE("Deserialization Error: %@", errString);
            }
        }
        
        // Always include a data entry, even if it is empty
        if (!eventData) {
            eventData = [[NSMutableDictionary alloc] init];
        }
        
        [eventData setValue:[event objectForKey:@"session_id"] forKey:@"session_id"];
        [event setValue:eventData forKey:@"data"];
        
        // Remove unused DB values
        for (NSString *key in [event allKeys]) {
            if (![topLevelKeys containsObject:key]) {
                [event removeObjectForKey:key];
            }
        }
    }
    
    if (batchEventCount < [events count]) {
        events = [events subarrayWithRange:NSMakeRange(0, batchEventCount)];
    }
    
    return events;
}

- (NSTimeInterval)timeToWaitBeforeSendingNextBatch {
    NSTimeInterval delay = 0;
    NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
    if (timeSinceLastSend < self.minBatchInterval) {
        delay = self.minBatchInterval - timeSinceLastSend;
    }
    return delay;
}

- (UAHTTPConnectionOperation *)sendOperationWithEvents:(NSArray *)events {

    UAHTTPRequest *analyticsRequest = [self analyticsRequest];

    [analyticsRequest appendBodyData:[NSJSONSerialization dataWithJSONObject:events
                                                                     options:0
                                                                       error:nil]];
    
    UA_LTRACE(@"Sending to server: %@", self.config.analyticsURL);
    UA_LTRACE(@"Sending analytics headers: %@", [analyticsRequest.headers descriptionWithLocale:nil indent:1]);
    UA_LTRACE(@"Sending analytics body: %@", [NSJSONSerialization stringWithObject:events options:NSJSONWritingPrettyPrinted]);

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        UA_LDEBUG(@"Analytics data sent successfully. Status: %ld", (long)[request.response statusCode]);
        UA_LTRACE(@"responseData=%@, length=%lu", request.responseString, (unsigned long)[request.responseData length]);
        self.lastSendTime = [NSDate date];

        // Update analytics settings with new header values
        [self updateAnalyticsParametersWithHeaderValues:request.response];
        
        if ([request.response statusCode] == 200) {
            [[UAAnalyticsDBManager shared] deleteEvents:events];
            [self resetEventsDatabaseStatus];
        } else {
            UA_LTRACE(@"Send analytics data request failed: %ld", (long)[request.response statusCode]);
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Send analytics data request failed.");
        self.lastSendTime = [NSDate date];
    };

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:analyticsRequest
                                                                                 onSuccess:successBlock
                                                                                 onFailure:failureBlock];
    return operation;
}

- (NSBlockOperation *)batchOperationWithCompletionBlock:(UAAnalyticsUploadCompletionBlock)completionBlock {

    NSBlockOperation *batchOperation = [NSBlockOperation blockOperationWithBlock:^{

        //in case the facts on the ground have changed since we last checked
        if (![self shouldSendAnalytics]) {
            UA_LTRACE(@"shouldSendAnalytics returned NO, skiping batchOperation");
            completionBlock();
        }

        NSArray* events = [self prepareEventsForUpload];

        //this could indicate a read problem, or simply an empty database
        if (!events) {
            UA_LTRACE(@"Empty database or error parsing events into array, skipping batchOperation");
            completionBlock();
            return;
        }

        //unlikely, due to the checks above, but theoretically possible
        if (events.count == 0) {
            UA_LTRACE(@"No events to upload, skipping batchOperation");
            completionBlock();
            return;
        }

        UAHTTPConnectionOperation *sendOperation = [self sendOperationWithEvents:events];

        [self.queue addOperation:sendOperation];

        NSBlockOperation *rebatchOperation = [NSBlockOperation blockOperationWithBlock:^{
            //if we're not in the background, and there's still stuff to send, create a new delay/batch and add them
            //otherwise, we should complete here and return
            BOOL moreBatchesNecessary = [self hasEventsToSend];

            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive && moreBatchesNecessary) {
                [self batchAndSendEventsWithCompletionBlock:completionBlock];
            } else {
                if (!moreBatchesNecessary) {
                    UA_LTRACE(@"No more events to upload.");
                } else {
                    UA_LTRACE(@"Application state is background or inactive, not sending any more batches.");
                }
                completionBlock();
            }
        }];

        [rebatchOperation addDependency:sendOperation];

        [self.queue addOperation:rebatchOperation];
    }];

    return batchOperation;
}

- (void)batchAndSendEventsWithCompletionBlock:(UAAnalyticsUploadCompletionBlock)completionBlock {

    NSTimeInterval delay = [self timeToWaitBeforeSendingNextBatch];

    if (delay) {
        UA_LTRACE(@"Scheduling analytics batch update in %g seconds.", delay);
    }

    UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:delay];
    NSBlockOperation *batchOperation = [self batchOperationWithCompletionBlock:completionBlock];

    [batchOperation addDependency:delayOperation];

    [self.queue addOperation:delayOperation];
    [self.queue addOperation:batchOperation];
}

//NOTE: this method is intended to be called from the main thread
- (void)sendEventsWithCompletionBlock:(UAAnalyticsUploadCompletionBlock)completionBlock {
    UA_LTRACE(@"Attempting to send analytics.");

    if (self.isSending) {
        UA_LTRACE(@"Analytics upload in progress, skipping analytics send.");
        return;
    }

    if (![self shouldSendAnalytics]) {
        UA_LTRACE(@"ShouldSendAnalytics returned NO, skipping analytics send.");
        completionBlock();
        return;
    }

    self.isSending = YES;

    [self batchAndSendEventsWithCompletionBlock:completionBlock];
}

//NOTE: this method is intended to be called from the main thread
- (void)send {
    [self sendEventsWithCompletionBlock:^{
        // Marshall this onto the main queue, in case the block is called in the background 
        [[NSOperationQueue mainQueue] addOperation:[NSBlockOperation blockOperationWithBlock:^{
            [self invalidateBackgroundTask];
            self.isSending = NO;
        }]];
    }];
}

@end
