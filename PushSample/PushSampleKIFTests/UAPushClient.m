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

#import "UAPushClient.h"

#import "UAirship.h"
#import "UAPush.h"
#import "UAConfig+Internal.h"
#import "UAHTTPConnection.h"

@implementation UAPushClient

+ (void)sendAlert:(NSString *)alert toDeviceToken:(NSString *)deviceToken {
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"aps":[NSMutableDictionary dictionary]}];
    [payload setValue:[NSArray arrayWithObject:deviceToken] forKeyPath:@"device_tokens"];
    [payload setValue:alert forKeyPath:@"aps.alert"];

    [UAPushClient sendAlertWithPayload:payload];
}

+ (void)sendAlert:(NSString *)alert toTag:(NSString *)tag {
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"aps":[NSMutableDictionary dictionary]}];
    [payload setValue:[NSArray arrayWithObject:tag] forKeyPath:@"tags"];
    [payload setValue:alert forKeyPath:@"aps.alert"];

    [UAPushClient sendAlertWithPayload:payload];
}

+ (void)sendAlert:(NSString *)alert toAlias:(NSString *)alias {
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"aps":[NSMutableDictionary dictionary]}];
    [payload setValue:[NSArray arrayWithObject:alias] forKeyPath:@"aliases"];
    [payload setValue:alert forKeyPath:@"aps.alert"];

    [UAPushClient sendAlertWithPayload:payload];

}

+ (void)sendAlertWithPayload:(NSDictionary *)payload {
    UAHTTPRequest *request = [UAPushClient pushRequestWithURLString:@"https://go.urbanairship.com/api/push/"];
    NSError *err = nil;
    [request appendBodyData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&err]];

    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:request];
    connection.successBlock = ^(UAHTTPRequest *r) {
        NSLog(@"Response Code: %ld", (long)r.response.statusCode);
        NSLog(@"Response Body: %@", [NSString stringWithUTF8String:[[request responseData] bytes]]);
    };
    [connection start];
    NSLog(@"payload: %@", payload);
}

+ (void)sendBroadcastAlert:(NSString *)alert {

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"aps":[NSMutableDictionary dictionary]}];
    [payload setValue:alert forKeyPath:@"aps.alert"];

    UAHTTPRequest *request = [UAPushClient pushRequestWithURLString:@"https://go.urbanairship.com/api/push/broadcast/"];
    NSError *err = nil;
    [request appendBodyData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&err]];

    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:request];
    connection.successBlock = ^(UAHTTPRequest *r) {
        NSLog(@"Response Code: %ld", (long)r.response.statusCode);
        NSLog(@"Response Body: %@", [NSString stringWithUTF8String:[[request responseData] bytes]]);
    };
    [connection start];
}

+ (UAHTTPRequest *)pushRequestWithURLString:(NSString *)urlString {
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.username = [UAirship shared].config.appKey;
    request.password = [UAirship shared].config.testingMasterSecret;
    request.HTTPMethod = @"POST";
    [request addRequestHeader: @"Content-Type" value: @"application/json"];
    
    return request;
}

@end
