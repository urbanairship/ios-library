/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

#import "UAEvent.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "UA_Reachability.h"
#import "UAInboxUtils.h"
#import "UAPush.h"

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

@interface UAEvent ()

@property (nonatomic, copy) NSString *time;
@property (nonatomic, copy) NSString *event_id;
@property (nonatomic, strong) NSMutableDictionary *data;

@end

@implementation UAEvent

- (id)init {
    self = [super init];
    if (self) {
        self.event_id = [UAUtils UUID];
        self.data = [NSMutableDictionary dictionary];
        return self;
    }
    return nil;
}

+ (id)event {
    id obj = [[self alloc] init];
    return obj;
}

- (id)initWithContext:(NSDictionary *)context {
    if (self=[self init]) {
        [self gatherData:context];
        return self;
    }
    return nil;
}

+ (id)eventWithContext:(NSDictionary *)context {
    id obj = [[self alloc] initWithContext:context];
    return obj;
}

- (NSString*)getType {
    return @"base";
}

- (NSUInteger)getEstimatedSize {
    NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionary];
    [eventDictionary setObject:[self getType] forKey:@"type"];
    [eventDictionary setObject:self.time forKey:@"time"];
    [eventDictionary setObject:self.event_id forKey:@"event_id"];
    [eventDictionary setObject:self.data forKey:@"data"];
    

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:eventDictionary
                                                        options:0
                                                          error:nil];
    
    UA_LDEBUG(@"Estimated event size: %lu", (unsigned long)[jsonData length]);
    
    return [jsonData length];
}

- (void)addDataWithValue:(id)value forKey:(NSString*)key {
    if (value && key) {
        [self.data setObject:value forKey:key];
    }
}

- (void)addDataFromSessionWithKey:(NSString *)sessionKey forKey:(NSString *)dataKey {
    [self addDataWithValue:[[UAirship shared].analytics.session objectForKey:sessionKey] forKey:dataKey];
}

- (void)addDataFromSessionForKey:(NSString*)dataKey {
    [self addDataFromSessionWithKey:dataKey forKey:dataKey];
}

- (void)gatherIndividualData:(NSDictionary*)context{}

- (void)gatherData:(NSDictionary*)context {
    // in case we re-use a event object
    self.time = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    [self.data removeAllObjects];

    // gather individual data
    [self gatherIndividualData:context];
}


@end

@implementation UAEventAppInit

- (NSString*)getType {
    return @"app_init";
}

- (void)gatherIndividualData:(NSDictionary*)context {
    [self addDataWithValue:[UAUser defaultUser].username forKey:@"user_id"];
    [self addDataFromSessionForKey:@"connection_type"];
    [self addDataFromSessionWithKey:@"launched_from_push_id" forKey:@"push_id"];
    [self addDataFromSessionWithKey:@"launched_from_rich_push_id" forKey:@"rich_push_id"];
    [self addDataFromSessionForKey:@"foreground"];
    
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = netInfo.subscriberCellularProvider;

    [self addDataWithValue:carrier.carrierName forKey:@"carrier"];

    [self addDataFromSessionForKey:@"time_zone"];
    [self addDataFromSessionForKey:@"daylight_savings"];
    [self addDataFromSessionForKey:@"notification_types"];
    
    // Component Versions
    [self addDataFromSessionForKey:@"os_version"];
    [self addDataFromSessionForKey:@"lib_version"];
    [self addDataFromSessionForKey:@"package_version"];
    
}

- (NSUInteger)getEstimatedSize {
    return kEventAppInitSize;
}

@end

@implementation UAEventAppForeground

- (NSString*)getType {
    return @"app_foreground";
}

- (void)gatherIndividualData:(NSDictionary*)context {
    [super gatherIndividualData:context];
    [self.data removeObjectForKey:@"foreground"];//not necessary - even is an explicit foreground
}

@end

@implementation UAEventAppExit

- (NSString *)getType {
    return @"app_exit";
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [self addDataFromSessionForKey:@"connection_type"];
    [self addDataFromSessionWithKey:@"launched_from_push_id" forKey:@"push_id"];
    [self addDataFromSessionWithKey:@"launched_from_rich_push_id" forKey:@"rich_push_id"];
}

- (NSUInteger)getEstimatedSize {
    return kEventAppExitSize;
}

@end

@implementation UAEventAppBackground

- (NSString *)getType {
    return @"app_background";
}

@end

@implementation UAEventAppActive

- (NSString *)getType {
    return @"activity_started";
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [self.data setValue:@"" forKey:@"class_name"];
}

- (NSUInteger)getEstimatedSize {
    return kEventAppActiveSize;
}

@end

@implementation UAEventAppInactive
 
- (NSString *)getType {
    return @"activity_stopped";
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [self.data setValue:@"" forKey:@"class_name"];
}

- (NSUInteger)getEstimatedSize {
    return kEventAppInactiveSize;
}

@end

@implementation UAEventDeviceRegistration

- (NSString *)getType {
    return @"device_registration";
}

- (void)gatherIndividualData:(NSDictionary *)context {
    [self addDataWithValue:[UAPush shared].deviceToken forKey:@"device_token"];
    [self addDataWithValue:[UAUser defaultUser].username forKey:@"user_id"];
}

- (NSUInteger)getEstimatedSize {
    return kEventDeviceRegistrationSize;
}

@end

@implementation UAEventPushReceived

- (NSString *)getType {
    return @"push_received";
}

- (void)gatherIndividualData:(NSDictionary *)context {

    [UAInboxUtils getRichPushMessageIDFromNotification:context withAction:^(NSString *richPushId){
        [self addDataWithValue:richPushId forKey:@"rich_push_id"];
    }];
    
    //Add the std push id, if present, else create a UUID
    NSString *pushId = [context objectForKey:@"_"];
    if (pushId) {
        [self addDataWithValue:pushId forKey:@"push_id"];
    } else {
        [self addDataWithValue:[UAUtils UUID] forKey:@"push_id"];
    }
}

- (NSUInteger)getEstimatedSize {
    return kEventPushReceivedSize;
}

@end




