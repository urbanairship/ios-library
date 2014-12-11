/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#import "UAEvent+Internal.h"
#import "UA_Reachability.h"
#import "UAPush.h"

@implementation UAEvent

/*
 * Fix for CTTelephonyNetworkInfo bug where instances might receive
 * notifications after being deallocated causes EXC_BAD_ACCESS exceptions. We
 * suspect that it is an iOS6 only issue.
 *
 * http://stackoverflow.com/questions/14238586/coretelephony-crash/15510580#15510580
 */
static CTTelephonyNetworkInfo *netInfo_;
static dispatch_once_t netInfoDispatchToken_;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.eventId = [NSUUID UUID].UUIDString;
        self.time = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
        return self;
    }
    return nil;
}

- (BOOL)isValid {
    return YES;
}

- (NSString *)eventType {
    return @"base";
}

- (NSUInteger)estimatedSize {
    NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionary];
    [eventDictionary setValue:self.eventType forKey:@"type"];
    [eventDictionary setValue:self.time forKey:@"time"];
    [eventDictionary setValue:self.eventId forKey:@"event_id"];
    [eventDictionary setValue:self.data forKey:@"data"];
    

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:eventDictionary
                                                        options:0
                                                          error:nil];
    
    UA_LTRACE(@"Estimated event size: %lu", (unsigned long)[jsonData length]);
    
    return [jsonData length];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAEvent ID: %@ type: %@ time: %@ data: %@",
            self.eventId, self.eventType, self.time, self.data];
}

- (NSString *)connectionType {
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

    return connectionTypeString;
}

- (NSString *)carrierName {
    dispatch_once(&netInfoDispatchToken_, ^{
        netInfo_ = [[CTTelephonyNetworkInfo alloc] init];
    });
    return netInfo_.subscriberCellularProvider.carrierName;
}

- (NSArray *)notificationTypes {
    NSMutableArray *notificationTypes = [NSMutableArray array];

    UIUserNotificationType enabledTypes = [[UAPush shared] currentEnabledNotificationTypes];

    if ((UIUserNotificationTypeBadge & enabledTypes) > 0) {
        [notificationTypes addObject:@"badge"];
    }

    if ((UIUserNotificationTypeSound & enabledTypes) > 0) {
        [notificationTypes addObject:@"sound"];
    }

    if ((UIUserNotificationTypeAlert & enabledTypes) > 0) {
        [notificationTypes addObject:@"alert"];
    }

    return notificationTypes;
}

- (id)debugQuickLookObject {
    return self.data.description;
}

@end




