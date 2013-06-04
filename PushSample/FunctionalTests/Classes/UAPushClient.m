//
//  UAPushClient.m
//  PushSampleLib
//
//  Created by Jeff Towle on 6/3/13.
//
//

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
        NSLog(@"Response Code: %d", r.response.statusCode);
        NSLog(@"Response Body: %@", [NSString stringWithUTF8String:[[request responseData] bytes]]);
    };
    [connection start];
}

+ (void)sendBroadcastAlert:(NSString *)alert {

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"aps":[NSMutableDictionary dictionary]}];
    [payload setValue:alert forKeyPath:@"aps.alert"];

    UAHTTPRequest *request = [UAPushClient pushRequestWithURLString:@"https://go.urbanairship.com/api/push/broadcast/"];
    NSError *err = nil;
    [request appendBodyData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&err]];

    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:request];
    connection.successBlock = ^(UAHTTPRequest *r) {
        NSLog(@"Response Code: %d", r.response.statusCode);
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
