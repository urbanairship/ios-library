
#import "UAUserAPIClient.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAHTTPRequestEngine.h"
#import "UAUtils.h"
#import "UAPush.h"
#import "UA_SBJsonWriter.h"
#import "UA_SBJsonParser.h"

@interface UAUserAPIClient()
@property(nonatomic, retain) UAHTTPRequestEngine *requestEngine;
@end

@implementation UAUserAPIClient

- (id)init {
    if (self = [super init] ) {
        self.requestEngine= [[[UAHTTPRequestEngine alloc] init] autorelease];
    }

    return self;
}

- (void)dealloc {
    self.requestEngine = nil;
    [super dealloc];
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

    NSDictionary *data = [self createUserDictionaryWithDeviceToken:deviceToken];


    UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
    NSString *body = [writer stringWithObject:data];

    UA_LDEBUG(@"Create user with body: %@", body);

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    return request;
}

- (UAHTTPRequest *)requestToUpdateDeviceToken:(NSString *)deviceToken forUsername:(NSString *)username {

    NSDictionary *dict = @{@"device_tokens" :@{@"add" : @[deviceToken]}};

    UA_LDEBUG(@"Updating user");

    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
								 [UAirship shared].config.deviceAPIURL,
								 @"/api/user/",
								 username];

    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];

	// Now do the user update, and pass out "master list" of deviceTokens back to the server
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"POST"];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];

    UA_SBJsonWriter *writer = [[UA_SBJsonWriter new] autorelease];
    NSString *body = [writer stringWithObject:dict];

    UA_LDEBUG(@"Update user with content: %@", body);

    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

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
        return (BOOL)(status >= 500 && status <= 599);
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
        NSDictionary *result = [parser objectWithString:request.responseString];

        NSString *username = [result objectForKey:@"user_id"];
        NSString *password = [result objectForKey:@"password"];
        NSString *url = [result objectForKey:@"user_url"];

        UAUserData *data = [UAUserData dataWithUsername:username password:password url:url];

        successBlock(data, deviceToken);
        
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        failureBlock(request);
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
        return (BOOL)(status >= 500 && status <= 599);
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        // The dictionary for the post body is built as follows in updateDeviceToken
        //    "device_tokens" =     {
        //        add =         (
        //                       a3dce91afd4aa3d2c44a66f2ef7be03b42ac05558ac6bdc2263a60b634f1c78a
        //                       );
        //    };
        // That's what we expect here, an NSDictionary for the key @"device_tokens" with a single NSArray for the key @"add"

        UA_LDEBUG(@"Update Device Token succeeded with response: %d", [request.response statusCode]);

        NSString *rawJson = [[[NSString alloc] initWithData:request.body  encoding:NSASCIIStringEncoding] autorelease];
        UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
        // If there is an error, it already failed on the server, and didn't get back here, so no use checking for JSON error
        NSDictionary *postBody = [parser objectWithString:rawJson];
        NSArray *add = [[postBody valueForKey:@"device_tokens"] valueForKey:@"add"];
        NSString *successfullyUploadedDeviceToken = ([add count] >= 1) ? [add objectAtIndex:0] : nil;

        successBlock(successfullyUploadedDeviceToken);
        
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        if (request.response) {
            // If we got an other than 200/201, that's just odd

            UA_LDEBUG(@"Update request did not succeed with expected response: %d", [request.response statusCode]);
        } else {
            UA_LDEBUG(@"Update request failed");
        }
        failureBlock(request);
    }];
}


@end
