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

#import "UAAnalytics+Internal.h"

#import "UAirship.h"
#import "UAAnalyticsDBManager.h"
#import "UALocationEvent.h"
#import "UAUser.h"
#import "UAConfig.h"
#import "UAHTTPConnectionOperation.h"
#import "UADelayOperation.h"
#import "UAInboxUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush+Internal.h"
#import "UAUtils.h"
#import "UAEventAppBackground.h"
#import "UAEventPushReceived.h"
#import "UAEventAppBackground.h"
#import "UAEventAppForeground.h"


typedef void (^UAAnalyticsUploadCompletionBlock)(void);

@implementation UAAnalytics

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.queue cancelAllOperations];
}

- (instancetype)initWithConfig:(UAConfig *)airshipConfig {
    self = [super init];
    if (self) {
        //set server to default if not specified in options
        self.config = airshipConfig;
        
        [self resetEventsDatabaseStatus];

        [self restoreSavedUploadEventSettings];
        [self saveUploadEventSettings];//save defaults to store lastSendTime if this was an initial condition

        
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

        
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;

        [self startSession];
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

#pragma mark -
#pragma mark Application State

- (void)enterForeground {
    UA_LTRACE(@"Enter Foreground.");

    // do not send the foreground event yet, as we are not actually in the foreground
    // (we are merely in the process of foregorunding)
    // set this flag so that the even will be sent as soon as the app is active.
    self.isEnteringForeground = YES;
}

- (void)enterBackground {
    UA_LTRACE(@"Enter Background.");

    // add app_background event
    [self addEvent:[UAEventAppBackground event]];

    self.notificationUserInfo = nil;
    [self clearSession];
}


- (void)didBecomeActive {
    UA_LTRACE(@"Application did become active.");
    
    // If this is the first 'inactive->active' transition in this session,
    // send 
    if (self.isEnteringForeground) {
        self.isEnteringForeground = NO;
        
        // Start a new session
        [self startSession];

        //add app_foreground event
        [self addEvent:[UAEventAppForeground event]];
    }

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
    self.maxTotalDBSize = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:kMaxTotalDBSizeUserDefaultsKey];
    self.maxBatchSize = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:kMaxBatchSizeUserDefaultsKey];
    self.maxWait = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:kMaxWaitUserDefaultsKey];
    self.minBatchInterval = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:kMinBatchIntervalUserDefaultsKey];
}

- (void)saveUploadEventSettings {
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.maxTotalDBSize forKey:kMaxTotalDBSizeUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.maxBatchSize forKey:kMaxBatchSizeUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.maxWait forKey:kMaxWaitUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)self.minBatchInterval forKey:kMinBatchIntervalUserDefaultsKey];
}

#pragma mark -
#pragma mark Analytics

- (void)handleNotification:(NSDictionary*)userInfo inApplicationState:(UIApplicationState)applicationState {
    switch (applicationState) {
        case UIApplicationStateActive:
            [self addEvent:[UAEventPushReceived eventWithNotification:userInfo]];
            break;
        case UIApplicationStateInactive:
            self.notificationUserInfo = userInfo;
            break;
        case UIApplicationStateBackground:
            break;
    }
}

- (void)addEvent:(UAEvent *)event {
    if (!event.isValid) {
        UA_LWARN(@"Dropping invalid event %@.", event);
        return;
    }

    if (self.config.analyticsEnabled) {
        UA_LDEBUG(@"Adding %@ event %@.", event.eventType, event.eventId);

        [[UAAnalyticsDBManager shared] addEvent:event withSessionId:self.sessionId];
        UA_LTRACE(@"Added: %@.", event);

        self.databaseSize += event.estimatedSize;
        if (self.oldestEventTime == 0) {
            self.oldestEventTime = [event.time doubleValue];
        }

        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground
            && event.eventType == UALocationEventAnalyticsType) {

            NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];

            if (timeSinceLastSend >= kMinBackgroundLocationIntervalSeconds) {
                [self send];
            } else {
                UA_LTRACE("Skipping send, background location events batch for 15 minutes.");
            }
        } else {
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
        self.maxTotalDBSize = (NSUInteger)[maxTotalValue integerValue] * 1024; //value returned in KB;
    }

    id maxBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Batch"];
    if (maxBatchValue) {
        self.maxBatchSize = (NSUInteger)[maxBatchValue integerValue] * 1024; //value return in KB
    }

    id maxWaitValue = [[response allHeaderFields] objectForKey:@"X-UA-Max-Wait"];
    if (maxWaitValue) {
        self.maxWait = (NSUInteger)[maxWaitValue integerValue];
    }

    id minBatchValue = [[response allHeaderFields] objectForKey:@"X-UA-Min-Batch-Interval"];
    if (minBatchValue) {
        self.minBatchInterval = (NSUInteger)[minBatchValue integerValue];
    }

    [self saveUploadEventSettings];
}

#pragma mark - 
#pragma mark Custom Property Setters
- (void)setMaxTotalDBSize:(NSUInteger)maxTotalDBSize {
    if (maxTotalDBSize < kMinTotalDBSizeBytes) {
        _maxTotalDBSize = kMinTotalDBSizeBytes;
    }else if (maxTotalDBSize > kMaxTotalDBSizeBytes) {
        _maxTotalDBSize = kMaxTotalDBSizeBytes;
    } else {
        _maxTotalDBSize = maxTotalDBSize;
    }
}

- (void)setMaxBatchSize:(NSUInteger)maxBatchSize {
    if (maxBatchSize < kMinBatchSizeBytes) {
        _maxBatchSize = kMinBatchSizeBytes;
    }else if (maxBatchSize > kMaxBatchSizeBytes) {
        _maxBatchSize = kMaxBatchSizeBytes;
    } else {
        _maxBatchSize = maxBatchSize;
    }
}

- (void)setMaxWait:(NSUInteger)maxWait {
    if (maxWait < kMinWaitSeconds) {
        _maxWait = kMinWaitSeconds;
    }else if (maxWait > kMaxWaitSeconds) {
        _maxWait = kMaxWaitSeconds;
    } else {
        _maxWait = maxWait;
    }
}

- (void)setMinBatchInterval:(NSUInteger)minBatchInterval {
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

- (UAHTTPRequest*)analyticsRequest {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.analyticsURL, @"/warp9/"];
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.compressBody = YES;//enable GZIP
    request.HTTPMethod = @"POST";

    // Required Items
    [request addRequestHeader:@"X-UA-Device-Family" value:[UIDevice currentDevice].systemName];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];

    [request addRequestHeader:@"X-UA-Package-Name" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey]];
    [request addRequestHeader:@"X-UA-Package-Version" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey] ?: @""];
    [request addRequestHeader:@"X-UA-ID" value:[UAUtils deviceID]];
    [request addRequestHeader:@"X-UA-User-ID" value:[UAUser defaultUser].username];
    [request addRequestHeader:@"X-UA-App-Key" value:[UAirship shared].config.appKey];

    [request addRequestHeader:@"X-UA-Channel-Opted-In" value:[[UAPush shared] userPushNotificationsAllowed] ? @"true" : @"false"];
    [request addRequestHeader:@"X-UA-Channel-Background-Enabled" value:[[UAPush shared] backgroundPushNotificationsAllowed] ? @"true" : @"false"];

    // Optional Items
    [request addRequestHeader:@"X-UA-Lib-Version" value:[UAirshipVersion get]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-OS-Version" value:[[UIDevice currentDevice] systemVersion]];
    [request addRequestHeader:@"Content-Type" value: @"application/json"];
    [request addRequestHeader:@"X-UA-Timezone" value:[[NSTimeZone defaultTimeZone] name]];
    [request addRequestHeader:@"X-UA-Locale-Language" value:[[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode]];
    [request addRequestHeader:@"X-UA-Locale-Country" value:[[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleCountryCode]];
    [request addRequestHeader:@"X-UA-Locale-Variant" value:[[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleVariantCode]];
    [request addRequestHeader:@"X-UA-Push-Address" value:[UAPush shared].deviceToken];
    [request addRequestHeader:@"X-UA-Channel-ID" value:[UAPush shared].channelID];

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
    NSUInteger batchEventCount = 0;
    
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

- (void)send {
    UA_LTRACE(@"Attempting to send analytics.");

    @synchronized(self) {

        if (!self.config.analyticsEnabled) {
            UA_LTRACE("Analytics disabled.");
            return;
        }

        if (![self hasEventsToSend]) {
            UA_LTRACE(@"No analytics events to upload.");
            return;
        }

        if (self.isSending) {
            UA_LTRACE(@"Analytics upload in progress, skipping analytics send.");
            return;
        }


        UA_LTRACE(@"Analytics send started.");

        __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            UA_LTRACE(@"Analytics background task expired.");
            @synchronized(self) {
                [self.queue cancelAllOperations];
                self.isSending = NO;
                if (backgroundTask != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                    backgroundTask = UIBackgroundTaskInvalid;
                }
            }
        }];

        if (backgroundTask == UIBackgroundTaskInvalid) {
            UA_LTRACE("Background task unavailable, skipping analytics");
            return;
        }

        self.isSending = YES;

        [self batchAndSendEventsWithCompletionBlock:^{
            UA_LTRACE(@"Analytics send completed.");
            @synchronized(self) {
                self.isSending = NO;
                if (backgroundTask != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                    backgroundTask = UIBackgroundTaskInvalid;
                }
            }
        }];
    }
}

- (void)launchedFromNotification:(NSDictionary *)notification {
    self.notificationUserInfo = notification;
    [self startSession];
}

- (void)clearSession {
    self.sessionId = @"";
    self.conversionSendId = nil;
    self.conversionRichPushId = nil;
}

- (void)startSession {
    [self clearSession];

    self.sessionId = [NSUUID UUID].UUIDString;
    if (self.notificationUserInfo) {

        // If the server did not send a push ID (likely because the payload did not have room)
        // generate an ID for the server to use
        self.conversionSendId = [self.notificationUserInfo objectForKey:@"_"] ?: [NSUUID UUID].UUIDString;

        NSString *richPushID = [UAInboxUtils getRichPushMessageIDFromNotification:self.notificationUserInfo];
        if (richPushID) {
            self.conversionRichPushId = richPushID;
        }
    }
}

@end
