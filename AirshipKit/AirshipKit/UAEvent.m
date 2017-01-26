/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UAEvent+Internal.h"
#import "UAPush.h"
#import "UAirship.h"

/*
 * Fix for CTTelephonyNetworkInfo bug where instances might receive
 * notifications after being deallocated causes EXC_BAD_ACCESS exceptions. We
 * suspect that it is an iOS6 only issue.
 *
 * http://stackoverflow.com/questions/14238586/coretelephony-crash/15510580#15510580
 */
static CTTelephonyNetworkInfo *netInfo_;
static dispatch_once_t netInfoDispatchToken_;

@implementation UAEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        self.eventID = [NSUUID UUID].UUIDString;
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

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAEvent ID: %@ type: %@ time: %@ data: %@",
            self.eventID, self.eventType, self.time, self.data];
}

- (NSString *)carrierName {
    dispatch_once(&netInfoDispatchToken_, ^{
        netInfo_ = [[CTTelephonyNetworkInfo alloc] init];
    });
    return netInfo_.subscriberCellularProvider.carrierName;
}

- (NSArray *)notificationTypes {
    NSMutableArray *notificationTypes = [NSMutableArray array];

    UANotificationOptions authorizedOptions = [UAirship push].authorizedNotificationOptions;

    if ((UANotificationOptionBadge & authorizedOptions) > 0) {
        [notificationTypes addObject:@"badge"];
    }

    if ((UANotificationOptionSound & authorizedOptions) > 0) {
        [notificationTypes addObject:@"sound"];
    }

    if ((UANotificationOptionAlert & authorizedOptions) > 0) {
        [notificationTypes addObject:@"alert"];
    }

    return notificationTypes;
}

- (NSUInteger)jsonEventSize {
    NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionary];
    [eventDictionary setValue:self.eventType forKey:@"type"];
    [eventDictionary setValue:self.time forKey:@"time"];
    [eventDictionary setValue:self.eventID forKey:@"event_id"];
    [eventDictionary setValue:self.data forKey:@"data"];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:eventDictionary
                                                       options:0
                                                         error:nil];

    return [jsonData length];
}

- (id)debugQuickLookObject {
    return self.data.description;
}

@end
