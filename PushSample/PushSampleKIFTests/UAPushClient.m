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
    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:deviceToken forKey:@"device_token"];

    [UAPushClient sendAlertWithPayload:[self createPayload:audience alert:alert]];
}

+ (void)sendAlert:(NSString *)alert toTag:(NSString *)tag {
    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:tag forKey:@"tag"];

    [UAPushClient sendAlertWithPayload:[self createPayload:audience alert:alert]];
}

+ (void)sendAlert:(NSString *)alert toAlias:(NSString *)alias {
    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:alias forKey:@"alias"];

    [UAPushClient sendAlertWithPayload:[self createPayload:audience alert:alert]];
}

+ (void)sendAlert:(NSString *)alert toNamedUser:(NSString *)namedUser {
    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:namedUser forKey:@"named_user"];

    [UAPushClient sendAlertWithPayload:[self createPayload:audience alert:alert]];
}

+ (void)sendAlert:(NSString *)alert toChannel:(NSString *)channel {
    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:channel forKey:@"ios_channel"];

    [UAPushClient sendAlertWithPayload:[self createPayload:audience alert:alert]];
}

+ (void)sendAlertWithPayload:(NSDictionary *)payload {
    UAHTTPRequest *request = [UAPushClient pushRequestWithURLString:@"https://go.urbanairship.com/api/push/"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];
    [request addRequestHeader: @"Content-Type" value: @"application/json"];

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
    [UAPushClient sendAlertWithPayload:[self createPayload:nil alert:alert]];
}

+ (UAHTTPRequest *)pushRequestWithURLString:(NSString *)urlString {
    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:urlString];
    request.username = [UAirship shared].config.appKey;
    request.password = [UAirship shared].config.testingMasterSecret;
    request.HTTPMethod = @"POST";
    [request addRequestHeader: @"Content-Type" value: @"application/json"];
    
    return request;
}

+ (NSDictionary *)createPayload:(NSDictionary *)audience alert:(NSString *)alert {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    if (audience) {
        [payload setValue:audience forKey:@"audience"];
    } else {
        [payload setValue:@"all" forKey:@"audience"];
    }

    [payload setValue:[NSArray arrayWithObject:@"ios"] forKey:@"device_types"];

    NSMutableDictionary *notification = [NSMutableDictionary dictionary];
    [notification setValue:alert forKey:@"alert"];

    [payload setValue:notification forKey:@"notification"];
    return payload;
}

@end
