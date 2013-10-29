
#import "UAUserAPIClient.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAHTTPRequestEngine.h"
#import "UAUtils.h"
#import "UAPush.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UAUserAPIClient()
@property(nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@end

@implementation UAUserAPIClient

- (id)init {
    self = [super init];
    if (self) {
        self.requestEngine= [[UAHTTPRequestEngine alloc] init];
    }

    return self;
}


- (NSDictionary *)createUserDictionaryWithDeviceToken:(NSString *)deviceToken
                                        withChannelID:(NSString *)channelID {

    //set up basic payload
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":[UAUtils deviceID]}];

    if (channelID.length) {
        [data setObject:@[channelID] forKey:@"channel_ids"];
    } else if (deviceToken.length) {
        [data setObject:@[deviceToken] forKey:@"device_tokens"];
    }

    return data;
}

- (NSDictionary *)updateUserDictionaryWithDeviceToken:(NSString *)deviceToken
                                        withChannelID:(NSString *)channelID {

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [data setValue:@{@"add": @[channelID]} forKey:@"channel_ids"];

        if (deviceToken.length) {
            [data setValue:@{@"remove": @[deviceToken]} forKey:@"device_tokens"];
        }
    } else if (deviceToken.length) {
        [data setValue:@{@"add": @[deviceToken]} forKey:@"device_tokens"];
    }

    return data;
}

- (UAHTTPRequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/"];

    NSURL *createUrl = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:createUrl method:@"POST"];
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LDEBUG(@"Request to create user with body: %@", body);

    return request;
}

- (UAHTTPRequest *)requestToUpdateWithPaylod:(NSDictionary *)payload
                                 forUsername:(NSString *)username {

    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
                                 [UAirship shared].config.deviceAPIURL,
                                 @"/api/user/",
                                 username];

    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];

    // Now do the user update, and pass out "master list" of deviceTokens back to the server
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"POST"];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to update user with content: %@", body);

    return request;
}


- (void)createUserWithChannelID:(NSString *)channelID
                    deviceToken:(NSString *)deviceToken
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSDictionary *payload = [self createUserDictionaryWithDeviceToken:deviceToken withChannelID:channelID];
    UAHTTPRequest *request = [self requestToCreateUserWithPayload:payload];

    [self.requestEngine
     runRequest:request succeedWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(status == 201);
     } retryWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)((status >= 500 && status <= 599) || request.error);
     } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {

         NSDictionary *result = [NSJSONSerialization objectWithString:request.responseString];

         NSString *username = [result objectForKey:@"user_id"];
         NSString *password = [result objectForKey:@"password"];
         NSString *url = [result objectForKey:@"user_url"];

         UAUserData *data = [UAUserData dataWithUsername:username password:password url:url];

         if (successBlock) {
             successBlock(data, payload);
         } else {
             UA_LERR(@"missing successBlock");
         }
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         [UAUtils logFailedRequest:request withMessage:@"creating user"];
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)updateUser:(NSString *)username
       deviceToken:(NSString *)deviceToken
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    UA_LDEBUG(@"Updating user %@.", username);


    NSDictionary *payload = [self updateUserDictionaryWithDeviceToken:deviceToken withChannelID:channelID];
    UAHTTPRequest *request = [self requestToUpdateWithPaylod:payload
                                                 forUsername:username];

    [self.requestEngine runRequest:request succeedWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)((status >= 500 && status <= 599) || request.error);
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LDEBUG(@"User successfully updated.  Response: %@", request.responseString);
        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"updating user"];
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}



@end
