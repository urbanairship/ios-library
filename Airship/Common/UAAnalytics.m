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
#import "UIDevice+machine.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"
#import "UA_Reachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#define kAnalyticsProductionServer @"https://combine.urbanairship.com";

NSString * const UAAnalyticsOptionsRemoteNotificationKey = @"UAAnalyticsOptionsRemoteNotificationKey";
NSString * const UAAnalyticsOptionsServerKey = @"UAAnalyticsOptionsServerKey";

@implementation UAAnalytics

@synthesize server;
@synthesize session;

- (id)initWithOptions:(NSDictionary *)options {
    if (self = [super init]) {
        
        //set server to default if not specified in options
        self.server = [options objectForKey:UAAnalyticsOptionsServerKey];
        if (self.server == nil) {
            self.server = kAnalyticsProductionServer;
        }
        
        events = [[NSMutableArray alloc] init];
        session = [[NSMutableDictionary alloc] init];
        
        //setup session with push id
        BOOL launchedFromPush = [options objectForKey:UAAnalyticsOptionsRemoteNotificationKey] != nil;
        NSString *pushId = [[options objectForKey:UAAnalyticsOptionsRemoteNotificationKey] objectForKey:@"_uaid"];
        NSString *inboxId = [[options objectForKey:UAAnalyticsOptionsRemoteNotificationKey] objectForKey:@"_uamid"];
        
        if (pushId != nil) {
            [session setValue:pushId forKey:@"launched_from_push_id"];
        } else if (inboxId != nil) {
            [session setValue:inboxId forKey:@"launched_from_push_id"];
        } else if (launchedFromPush) {
            [session setValue:@"true" forKey:@"launched_from_push_id"];
        }
        
    }
    return self;
}

- (void)send {
    
    if (self.server == nil || [self.server length] == 0) {
        UALOG("Analytics disabled.");
        return;
    }
    UALOG(@"Sending to server: %@", self.server);
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           server, 
                           @"/warp9/"];
    NSURL *url = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                                  method:@"POST"
                                                delegate:self
                                                  finish:@selector(sendDataSucceeded:)
                                                    fail:@selector(sendDataFailed:)];
    UIDevice *device = [UIDevice currentDevice];
    
    [request addRequestHeader:@"X-UA-Library" value:UA_VERSION];
    [request addRequestHeader:@"X-UA-Device-Model" value:[device machine]];
    [request addRequestHeader:@"X-UA-Device-Family" value:device.systemName];
    [request addRequestHeader:@"X-UA-OS-Version" value:device.systemVersion];
    [request addRequestHeader:@"X-UA-Sent-At" value:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]]];
    
    //UALOG(@"Sending analytics headers: %@", [request.requestHeaders descriptionWithLocale:nil indent:1]);
    
    //replace event buffer
    NSArray *eventsToSend = events;
    events = [[NSMutableDictionary alloc] init];//replace with new event buffer
    
    if (eventsToSend != nil) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
        [request appendPostData:[[writer stringWithObject:eventsToSend] dataUsingEncoding:NSUTF8StringEncoding]];
        
        //UALOG(@"Sending analytics body: %@", [writer stringWithObject:eventsToSend]);
        
        [writer release];
        [eventsToSend release];
    }
    
    UALOG(@"Starting async analytics request.");
    [request setValidatesSecureCertificate:NO];
    [request startAsynchronous];
    
}

- (void)sendDataSucceeded:(UA_ASIHTTPRequest*)request {
    UALOG(@"Analytics data sent successfully. Status: %d", request.responseStatusCode);
}

- (void)sendDataFailed:(UA_ASIHTTPRequest*)request {
    UALOG(@"Send analytics data request failed.");
    [UAUtils requestWentWrong:request];
}

#pragma mark -
#pragma mark Analytics

- (NSMutableDictionary *)buildStartupMetadataDictionary {
    
    NSMutableDictionary *metadata = [[[NSMutableDictionary alloc] init] autorelease];
    [metadata setValue:[UAirship shared].appId forKey:@"app_key"];
    
    // Record time zone
    [metadata setValue:[[NSTimeZone systemTimeZone] abbreviation] forKey:@"time_zone"];
    
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
    [metadata setValue:connectionTypeString forKey:@"connection_type"];
    
    // Capture carrier info if available
    IF_IOS4_OR_GREATER(
                       
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = netInfo.subscriberCellularProvider;
        
        [metadata setValue:carrier.carrierName forKey:@"carrier"];
        
        [netInfo release];
    )
    
    return metadata;
}

- (void)addEvent:(NSMutableDictionary *)eventInfo withType:(NSString *)type {
    [eventInfo addEntriesFromDictionary:session];
    [events addObject:[UAAnalytics packagePayload:eventInfo withType:type]];
}

+ (NSDictionary *)packagePayload:(NSDictionary *)payload withType:(NSString *)typeString {
 
    NSMutableDictionary *data = [[[NSMutableDictionary alloc] init] autorelease];
    
    [data setObject:typeString forKey:@"type"];
    [data setObject:payload forKey:@"data"];
    [data setObject:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]] forKey:@"time"];
    
    return data;
    
}

- (void) dealloc {
    
    self.server = nil;
    
    RELEASE_SAFELY(events);
    RELEASE_SAFELY(session);
    
    [super dealloc];
}


@end
