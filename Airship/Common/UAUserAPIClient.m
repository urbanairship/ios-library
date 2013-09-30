
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


- (NSDictionary *)createUserDictionaryWithDeviceToken:(NSString *)deviceToken {

    //set up basic payload
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":[UAUtils deviceID]}];

    if (deviceToken) {
        [data setObject:@[deviceToken] forKey:@"device_tokens"];
    }

    return data;
}

- (UAHTTPRequest *)requestToCreateUserWithDeviceToken:(NSString *)deviceToken {
    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/"];

    NSURL *createUrl = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:createUrl method:@"POST"];
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSDictionary *data = [self createUserDictionaryWithDeviceToken:deviceToken];
    NSString *body = [NSJSONSerialization stringWithObject:data];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LDEBUG(@"Request to create user with body: %@", body);

    return request;
}

- (UAHTTPRequest *)requestToUpdateDeviceToken:(NSString *)deviceToken forUsername:(NSString *)username {

    NSDictionary *dict = @{@"device_tokens" :@{@"add" : @[deviceToken]}};

    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
                                 [UAirship shared].config.deviceAPIURL,
                                 @"/api/user/",
                                 username];

    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];

    // Now do the user update, and pass out "master list" of deviceTokens back to the server
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"POST"];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:dict];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to update user with content: %@", body);

    return request;
}

- (void)createUserOnSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                  onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    //if APN hasn't finished yet or is not enabled, don't include the deviceToken
    NSString* deviceToken = [UAPush shared].deviceToken;
    if (deviceToken && deviceToken.length == 0) {
            deviceToken = nil;
    }

    UAHTTPRequest *request = [self requestToCreateUserWithDeviceToken:deviceToken];
    
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
            successBlock(data, deviceToken);
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (void)updateDeviceToken:(NSString *)deviceToken
              forUsername:(NSString *)username
                onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
                onFailure:(UAUserAPIClientFailureBlock)failureBlock {
    UA_LDEBUG(@"Updating device token.");

    UAHTTPRequest *request = [self requestToUpdateDeviceToken:deviceToken forUsername:username];

    [self.requestEngine runRequest:request succeedWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)((status >= 500 && status <= 599) || request.error);
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        // The dictionary for the post body is built as follows in updateDeviceToken
        //    "device_tokens" =     {
        //        add =         (
        //                       a3dce91afd4aa3d2c44a66f2ef7be03b42ac05558ac6bdc2263a60b634f1c78a
        //                       );
        //    };
        // That's what we expect here, an NSDictionary for the key @"device_tokens" with a single NSArray for the key @"add"

        UA_LTRACE(@"Update Device Token succeeded with response: %ld", (long)[request.response statusCode]);

        NSString *rawJson = [[NSString alloc] initWithData:request.body  encoding:NSASCIIStringEncoding];

        // If there is an error, it already failed on the server, and didn't get back here, so no use checking for JSON error
        NSDictionary *postBody = [NSJSONSerialization objectWithString:rawJson];
        NSArray *add = [[postBody valueForKey:@"device_tokens"] valueForKey:@"add"];
        NSString *successfullyUploadedDeviceToken = ([add count] >= 1) ? [add objectAtIndex:0] : nil;

        if (successBlock) {
            successBlock(successfullyUploadedDeviceToken);
        } else {
            UA_LERR(@"missing successBlock");
        }
        
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        if (request.response) {
            // If we got an other than 200/201, that's just odd

            UA_LDEBUG(@"Update request did not succeed with expected response: %ld", (long)[request.response statusCode]);
        } else {
            UA_LDEBUG(@"Update request failed");
        }
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}


@end
