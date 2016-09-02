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

#import <UIKit/UIKit.h>
#import "UAAnalytics+Internal.h"
#import "UAEvent+Internal.h"

#import "UAirship.h"
#import "UAAnalyticsDBManager+Internal.h"
#import "UALocationEvent.h"
#import "UAUser.h"
#import "UAConfig.h"
#import "UAHTTPConnectionOperation+Internal.h"
#import "UADelayOperation+Internal.h"
#import "UAInboxUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush+Internal.h"
#import "UAUtils.h"
#import "UAAppBackgroundEvent+Internal.h"
#import "UAPushReceivedEvent+Internal.h"
#import "UAAppBackgroundEvent+Internal.h"
#import "UAAppForegroundEvent+Internal.h"
#import "UAScreenTrackingEvent+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UALocation.h"
#import "UARegionEvent+Internal.h"
#import "UAAssociateIdentifiersEvent+Internal.h"
#import "UAAssociatedIdentifiers.h"
#import "UACustomEvent.h"

typedef void (^UAAnalyticsUploadCompletionBlock)(void);


#define kUALocationPermissionSystemLocationDisabled @"SYSTEM_LOCATION_DISABLED";
#define kUALocationPermissionNotAllowed @"NOT_ALLOWED";
#define kUALocationPermissionAlwaysAllowed @"ALWAYS_ALLOWED";
#define kUALocationPermissionForegroundAllowed @"FOREGROUND_ALLOWED";
#define kUALocationPermissionUnprompted @"UNPROMPTED";
#define kUAAssociatedIdentifiers @"UAAssociatedIdentifiers"

@implementation UAAnalytics

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopSends];
}

- (instancetype)initWithConfig:(UAConfig *)airshipConfig dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.analyticsDBManager = [[UAAnalyticsDBManager alloc] init];
        // Set server to default if not specified in options
        self.config = airshipConfig;
        self.dataStore = dataStore;

        // Default analytics value
        if (![self.dataStore objectForKey:kUAAnalyticsEnabled]) {
            [self.dataStore setBool:YES forKey:kUAAnalyticsEnabled];
        }

        [self restoreSavedUploadEventSettings];

        // Save defaults to store lastSendTime if this was an initial condition
        [self saveUploadEventSettings];

        self.sendQueue = [[NSOperationQueue alloc] init];
        self.sendQueue.maxConcurrentOperationCount = 1;

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

        // Register for terminate notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willTerminate)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [self startSession];

        // Set the intial delay
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            self.earliestInitialSendTime = [NSDate dateWithTimeIntervalSinceNow:kInitialBackgroundBatchWaitSeconds];
        } else {
            self.earliestInitialSendTime = [NSDate dateWithTimeIntervalSinceNow:kInitialForegroundBatchWaitSeconds];
        }

        // Schedule a send
        [self sendWithDelay:self.timeToWaitBeforeSendingNextBatch];
    }

    return self;
}

+ (instancetype)analyticsWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAAnalytics alloc] initWithConfig:config dataStore:dataStore];
}

#pragma mark -
#pragma mark Application State

- (void)enterForeground {
    UA_LTRACE(@"Enter Foreground.");

    // Start tracking previous screen before backgrounding began
    [self trackScreen:self.previousScreen];

    // do not send the foreground event yet, as we are not actually in the foreground
    // (we are merely in the process of foregorunding)
    // set this flag so that the even will be sent as soon as the app is active.
    self.isEnteringForeground = YES;
}

- (void)enterBackground {
    UA_LTRACE(@"Enter Background.");

    [self stopTrackingScreen];

    // add app_background event
    [self addEvent:[UAAppBackgroundEvent event]];

    // Send immediately so we can end our background tasks as soon as possible
    [self sendWithDelay:0];

    self.notificationUserInfo = nil;
    [self clearSession];
}

- (void)willTerminate {
    UA_LTRACE(@"Application is terminating.");

    [self stopTrackingScreen];
}

- (void)didBecomeActive {
    UA_LTRACE(@"Application did become active.");

    // If this is the first 'inactive->active' transition in this session,
    // send 
    if (self.isEnteringForeground) {

        self.isEnteringForeground = NO;

        // Update the initial send delay
        self.earliestInitialSendTime = [NSDate dateWithTimeIntervalSinceNow:kInitialForegroundBatchWaitSeconds];

        // Start a new session
        [self startSession];

        //add app_foreground event
        [self addEvent:[UAAppForegroundEvent event]];
    }

}

#pragma mark -
#pragma mark Preferences

- (NSDate *)lastSendTime {
    return [self.dataStore objectForKey:@"X-UA-Last-Send-Time"] ?: [NSDate distantPast];
}

- (void)setLastSendTime:(NSDate *)lastSendTime {
    if (lastSendTime) {
        [self.dataStore setObject:lastSendTime forKey:@"X-UA-Last-Send-Time"];
    }
}

- (void)restoreSavedUploadEventSettings {
    // If the key is missing the int will end up being 0 and the values will clamp to there lower end.
    self.maxTotalDBSize = (NSUInteger)[self.dataStore integerForKey:kMaxTotalDBSizeUserDefaultsKey];
    self.maxBatchSize = (NSUInteger)[self.dataStore integerForKey:kMaxBatchSizeUserDefaultsKey];
    self.maxWait = (NSUInteger)[self.dataStore integerForKey:kMaxWaitUserDefaultsKey];
    self.minBatchInterval = (NSUInteger)[self.dataStore integerForKey:kMinBatchIntervalUserDefaultsKey];
}

- (void)saveUploadEventSettings {
    [self.dataStore setInteger:(NSInteger)self.maxTotalDBSize forKey:kMaxTotalDBSizeUserDefaultsKey];
    [self.dataStore setInteger:(NSInteger)self.maxBatchSize forKey:kMaxBatchSizeUserDefaultsKey];
    [self.dataStore setInteger:(NSInteger)self.maxWait forKey:kMaxWaitUserDefaultsKey];
    [self.dataStore setInteger:(NSInteger)self.minBatchInterval forKey:kMinBatchIntervalUserDefaultsKey];
}

#pragma mark -
#pragma mark Analytics

- (void)addEvent:(UAEvent *)event {
    if (!event.isValid) {
        UA_LWARN(@"Dropping invalid event %@.", event);
        return;
    }

    if (!self.isEnabled) {
        UA_LTRACE(@"Analytics disabled, ignoring event: %@", event.eventType);
        return;
    }

    UA_LDEBUG(@"Adding %@ event %@.", event.eventType, event.eventID);
    [self.analyticsDBManager addEvent:event withSessionID:self.sessionID];

    id strongDelegate = self.delegate;
    if ([event isKindOfClass:[UACustomEvent class]]) {
        if ([strongDelegate respondsToSelector:@selector(customEventAdded:)]) {
            [strongDelegate customEventAdded:(UACustomEvent *)event];
        }
    }

    if ([event isKindOfClass:[UARegionEvent class]]) {
        if ([strongDelegate respondsToSelector:@selector(regionEventAdded:)]) {
            [strongDelegate regionEventAdded:(UARegionEvent *)event];
        }
    }

    UA_LTRACE(@"Added: %@.", event);

    switch (event.priority) {
        case UAEventPriorityHigh:
            [self sendWithDelay:kHighPriorityBatchWaitSeconds];
            break;
        case UAEventPriorityNormal:
            [self sendWithDelay:self.timeToWaitBeforeSendingNextBatch];
            break;
        case UAEventPriorityLow:
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                NSTimeInterval timeSinceLastSend = [[NSDate date] timeIntervalSinceDate:self.lastSendTime];
                if (timeSinceLastSend >= kMinBackgroundLowPriorityEventSendIntervalSeconds) {
                    [self sendWithDelay:0];
                } else {
                    UA_LTRACE("Skipping low priority event send.");
                }
            } else {
                [self sendWithDelay:self.timeToWaitBeforeSendingNextBatch];
            }
            break;
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

- (BOOL)hasEventsToSend {
    return self.analyticsDBManager.eventCount > 0;
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
    [request addRequestHeader:@"X-UA-Package-Version" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @""];
    [request addRequestHeader:@"X-UA-ID" value:[UAUtils deviceID]];
    [request addRequestHeader:@"X-UA-User-ID" value:[UAirship inboxUser].username];
    [request addRequestHeader:@"X-UA-App-Key" value:[UAirship shared].config.appKey];

    [request addRequestHeader:@"X-UA-Channel-Opted-In" value:[[UAirship push] userPushNotificationsAllowed] ? @"true" : @"false"];
    [request addRequestHeader:@"X-UA-Channel-Background-Enabled" value:[[UAirship push] backgroundPushNotificationsAllowed] ? @"true" : @"false"];

    // Optional Items
    [request addRequestHeader:@"X-UA-Lib-Version" value:[UAirshipVersion get]];
    [request addRequestHeader:@"X-UA-Device-Model" value:[UAUtils deviceModelName]];
    [request addRequestHeader:@"X-UA-OS-Version" value:[[UIDevice currentDevice] systemVersion]];
    [request addRequestHeader:@"Content-Type" value: @"application/json"];
    [request addRequestHeader:@"X-UA-Timezone" value:[[NSTimeZone defaultTimeZone] name]];
    [request addRequestHeader:@"X-UA-Locale-Language" value:[[NSLocale autoupdatingCurrentLocale] objectForKey:NSLocaleLanguageCode]];
    [request addRequestHeader:@"X-UA-Locale-Country" value:[[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleCountryCode]];
    [request addRequestHeader:@"X-UA-Locale-Variant" value:[[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleVariantCode]];

    if ([UAirship push].pushTokenRegistrationEnabled) {
        [request addRequestHeader:@"X-UA-Push-Address" value:[UAirship push].deviceToken];
    }
    [request addRequestHeader:@"X-UA-Channel-ID" value:[UAirship push].channelID];
    [request addRequestHeader:@"X-UA-Location-Permission" value:[self locationPermission]];

    [request addRequestHeader:@"X-UA-Location-Service-Enabled" value:[UAirship location].locationUpdatesEnabled ? @"true" : @"false"];

    return request;
}

-(void)invalidateTimer {
    if (!self.sendTimer.isValid) {
        return;
    }

    if (self.sendTimer.userInfo) {
        UIBackgroundTaskIdentifier backgroundTask = [self.sendTimer.userInfo unsignedIntegerValue];

        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
    }

    [self.sendTimer invalidate];
    self.sendTimer = nil;
}

- (void)stopSends {
    [self.sendQueue cancelAllOperations];
    [self invalidateTimer];
}


- (BOOL)isEventValid:(NSMutableDictionary *)event {
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
- (NSArray *)prepareEventsForUpload {
    NSUInteger databaseSize = self.analyticsDBManager.sizeInBytes;

    // Delete older events until the database size is met
    while (databaseSize > self.maxTotalDBSize) {
        UA_LTRACE(@"Database exceeds max size of %ld bytes... Deleting oldest session.", (long)self.maxTotalDBSize);
        [self.analyticsDBManager deleteOldestSession];
        databaseSize = self.analyticsDBManager.sizeInBytes;
    }


    if (![self hasEventsToSend]) {
        return nil;
    }

    NSUInteger avgEventSize = databaseSize / self.analyticsDBManager.eventCount;

    int actualSize = 0;
    NSUInteger batchEventCount = 0;
    
    NSArray *events = [self.analyticsDBManager getEvents:self.maxBatchSize/avgEventSize];
    NSArray *topLevelKeys = @[@"type", @"time", @"event_id", @"data"];

    for (NSMutableDictionary *event in events) {
        
        if (![self isEventValid:event]) {
            UA_LERR("Detected invalid event due to possible database corruption. Recreating database");
            [self.analyticsDBManager resetDB];
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
            NSError *err;
            eventData = (NSMutableDictionary *)[NSPropertyListSerialization
                                                propertyListWithData:serializedEventData
                                                             options:NSPropertyListMutableContainersAndLeaves
                                                              format:NULL /* an out param */
                                                               error:&err];
            
            if (err) {
                UA_LTRACE(@"Deserialization Error: %@", [err localizedDescription]);
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

    // Now worry about initial delay
    NSTimeInterval initialDelayRemaining = [self.earliestInitialSendTime timeIntervalSinceNow];

    return MAX(delay, initialDelayRemaining);
}

- (NSOperation *)uploadOperationWithEvents:(NSArray *)events {

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

        // Update analytics settings with new header values
        [self updateAnalyticsParametersWithHeaderValues:request.response];

        if ([request.response statusCode] == 200) {
            [self.analyticsDBManager deleteEvents:events];
        } else {
            UA_LTRACE(@"Analytics upload request failed: %ld", (long)[request.response statusCode]);
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Analytics upload request failed.");
    };

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:analyticsRequest
                                                                                 onSuccess:successBlock
                                                                                 onFailure:failureBlock];
    return operation;
}

// Adds event upload operation to the sendQueue.
- (NSOperation *)queryOperationWithCompletionBlock:(UAAnalyticsUploadCompletionBlock)completionBlock {
    __weak __block NSOperation *weakOperation;
    void (^operationCompletionHandler)() = ^ {
        NSArray *events = [self prepareEventsForUpload];

        // Check for empty events
        if (!events.count) {
            UA_LTRACE(@"No events to upload, skipping sendOperation.");
            return;
        }

        UA_LTRACE(@"Analytics upload in progress.");

        self.lastSendTime = [NSDate date];

        NSOperation *networkOperation = [self uploadOperationWithEvents:events];
        // Set the priority higher than the _outer_ send operation (normal priority)
        networkOperation.queuePriority = NSOperationQueuePriorityHigh;

        // Transfer to the completion block to the network operation
        networkOperation.completionBlock = completionBlock;
        weakOperation.completionBlock = nil;

        [self.sendQueue addOperation:networkOperation];
    };


    NSOperation *strongOperation = [NSBlockOperation blockOperationWithBlock:operationCompletionHandler];
    weakOperation = strongOperation;

    return strongOperation;
}

- (void)sendWithDelay:(NSTimeInterval)delay {
    UA_LTRACE(@"Attempting to send update.");

    if (![UAirship push].channelID) {
        UA_LTRACE("No channel ID, skipping send.");
        return;
    }

    if (!self.config.analyticsEnabled) {
        UA_LTRACE("Analytics disabled.");
        return;
    }

    if (![self hasEventsToSend]) {
        UA_LTRACE(@"No analytics events to upload.");
        return;
    }

    if (self.sendTimer.isValid && [self.sendTimer.fireDate compare:[NSDate dateWithTimeIntervalSinceNow:delay]] == NSOrderedAscending) {
        UA_LTRACE("Upload already scheduled with delay less than %f seconds.", delay);
        return;
    }

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        UA_LTRACE(@"Analytics background task expired.");
        [self stopSends];
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    // Invalidate the timer after creating a new background task
    [self invalidateTimer];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LTRACE("Background task unavailable, skipping analytics");
        return;
    }

    if (delay) {
        UA_LTRACE(@"Analytics data scheduled to send in %f seconds.", delay);
        self.sendTimer = [NSTimer timerWithTimeInterval:delay
                                                 target:self
                                               selector:@selector(sendTimerFired:)
                                               userInfo:@(backgroundTask)
                                                repeats:NO];

        [[NSRunLoop mainRunLoop] addTimer:self.sendTimer forMode:NSDefaultRunLoopMode];
    } else {
        [self enqueueSendOperationWithBackgroundTaskIdentifier:backgroundTask];
    }
}

// Enqueues another send operation with the timer's background task
- (void)sendTimerFired:(NSTimer *)timer {
    UIBackgroundTaskIdentifier backgroundTask = [timer.userInfo unsignedIntegerValue];
    [self enqueueSendOperationWithBackgroundTaskIdentifier:backgroundTask];
    [timer invalidate];

    if (self.sendTimer == timer) {
        self.sendTimer = nil;
    }
}

- (void)enqueueSendOperationWithBackgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTask {
    NSOperation *sendOperation = [self queryOperationWithCompletionBlock:^{
        UA_LTRACE(@"Analytics data send completed with background task: %lu", (unsigned long)backgroundTask);
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        }
    }];

    [self.sendQueue addOperation:sendOperation];
}

- (void)launchedFromNotification:(NSDictionary *)notification {
    self.notificationUserInfo = notification;
    [self startSession];
}

- (void)clearSession {
    self.sessionID = @"";
    self.conversionSendID = nil;
    self.conversionRichPushID = nil;
    self.conversionPushMetadata = nil;
}

- (void)startSession {
    [self clearSession];

    self.sessionID = [NSUUID UUID].UUIDString;
    if (self.notificationUserInfo) {

        // If the server did not send a push ID (likely because the payload did not have room)
        // then send "MISSING_SEND_ID"
        self.conversionSendID = [self.notificationUserInfo objectForKey:@"_"] ?: kUAMissingSendID;

        // If the server did not send the metadata, then set it to nil
        self.conversionPushMetadata = [self.notificationUserInfo objectForKey:kUAPushMetadata] ?: nil;

        NSString *richPushID = [UAInboxUtils inboxMessageIDFromNotification:self.notificationUserInfo];
        if (richPushID) {
            self.conversionRichPushID = richPushID;
        }
    }
}

- (BOOL)isEnabled {
    return [self.dataStore boolForKey:kUAAnalyticsEnabled] && self.config.analyticsEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    // If we are disabling the runtime flag clear all events
    if ([self.dataStore boolForKey:kUAAnalyticsEnabled] && !enabled) {
        UA_LINFO(@"Deleting all analytics events.");
        [self stopSends];
        [self.analyticsDBManager resetDB];
    }

    [self.dataStore setBool:enabled forKey:kUAAnalyticsEnabled];
}

- (void)associateDeviceIdentifiers:(UAAssociatedIdentifiers *)associatedIdentifiers {
    [self.dataStore setObject:associatedIdentifiers.allIDs forKey:kUAAssociatedIdentifiers];
    [self addEvent:[UAAssociateIdentifiersEvent eventWithIDs:associatedIdentifiers]];
}

- (UAAssociatedIdentifiers *)currentAssociatedDeviceIdentifiers {
    NSDictionary *storedIDs = [self.dataStore objectForKey:kUAAssociatedIdentifiers];
    return [UAAssociatedIdentifiers identifiersWithDictionary:storedIDs];
}

- (NSString *)locationPermission {
    if (![CLLocationManager locationServicesEnabled]) {
        return kUALocationPermissionSystemLocationDisabled;
    } else {
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusDenied:
            case kCLAuthorizationStatusRestricted:
                return kUALocationPermissionNotAllowed;
            case kCLAuthorizationStatusAuthorizedAlways:
                return kUALocationPermissionAlwaysAllowed;
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                return kUALocationPermissionForegroundAllowed;
            case kCLAuthorizationStatusNotDetermined:
                return kUALocationPermissionUnprompted;
        }
    }
}

- (void)trackScreen:(nullable NSString *)screen {

    // Prevent duplicate calls to track same screen
    if ([screen isEqualToString:self.currentScreen]) {
        return;
    }

    id strongDelegate = self.delegate;
    if (screen && [strongDelegate respondsToSelector:@selector(screenTracked:)]) {
        [strongDelegate screenTracked:screen];
    }

    // If there's a screen currently being tracked set it's stop time and add it to analytics
    if (self.currentScreen) {
        UAScreenTrackingEvent *ste = [UAScreenTrackingEvent eventWithScreen:self.currentScreen startTime:self.startTime];
        ste.stopTime = [NSDate date].timeIntervalSince1970;
        ste.previousScreen = self.previousScreen;

        // Set previous screen to last tracked screen
        self.previousScreen = self.currentScreen;

        // Add screen tracking event to next analytics batch
        [self addEvent:ste];
    }

    self.currentScreen = screen;
    self.startTime = [NSDate date].timeIntervalSince1970;
}

- (void) stopTrackingScreen {
    [self trackScreen:nil];
}

@end
