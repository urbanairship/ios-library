
#import "UADeviceAPIClient.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAHTTPConnectionOperation.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UADeviceRegistrationPayload.h"

#define kUAPushRetryTimeInitialDelay 60
#define kUAPushRetryTimeMultiplier 2
#define kUAPushRetryTimeMaxDelay 300
#define kUAPushDeviceTokensURLBase @"/api/device_tokens/"


@interface UADeviceAPIClient()
@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@end

@implementation UADeviceAPIClient

- (instancetype)init {
    self = [super init];
    if (self) {
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUAPushRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUAPushRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUAPushRetryTimeMultiplier;
        self.shouldRetryOnConnectionError = YES;
    }
    return self;
}

- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

- (NSURL *)deviceUrlWithToken:(NSString *)deviceToken {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].config.deviceAPIURL, kUAPushDeviceTokensURLBase, deviceToken];
    return [NSURL URLWithString:urlString];
}

- (UAHTTPRequest *)requestToRegisterDeviceToken:(NSString *)deviceToken withPayload:(UADeviceRegistrationPayload *)payload {
    NSURL *url = [self deviceUrlWithToken:deviceToken];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:url method:@"PUT"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    [request addRequestHeader: @"Content-Type" value: @"application/json"];
    [request appendBodyData:[payload asJSONData]];

    return request;
}

- (UAHTTPRequest *)requestToDeleteDeviceToken:(NSString *)deviceToken {
    NSURL *url = [self deviceUrlWithToken:deviceToken];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:url method:@"DELETE"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    return request;
}

- (void)runRequest:(UAHTTPRequest *)request
      succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
        retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
         onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
         onFailure:(UADeviceAPIClientFailureBlock)failureBlock {

    [self.requestEngine cancelAllRequests];


    [self.requestEngine
     runRequest:request
     succeedWhere:succeedWhereBlock
     retryWhere:retryWhereBlock
     onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         UA_LTRACE(@"DeviceAPI request succeeded: responseData=%@, length=%lu", request.responseString, (unsigned long)[request.responseData length]);

         //clear the pending cache,  update last successful cache
         if (successBlock) {
             successBlock();
         } else {
             UA_LERR(@"missing successBlock");
         }
     }
     onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         [UAUtils logFailedRequest:request withMessage:@"DeviceAPI request failed"];

         //clear the pending cache
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)registerDeviceToken:(NSString *)deviceToken
                withPayload:(UADeviceRegistrationPayload *)payload
                  onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                  onFailure:(UADeviceAPIClientFailureBlock)failureBlock {

    UAHTTPRequest *putRequest = [self requestToRegisterDeviceToken:deviceToken
                                                       withPayload:payload];

    UA_LTRACE(@"Registering device token with headers: %@, payload: %@",
              [putRequest.headers descriptionWithLocale:nil indent:1],
              [NSJSONSerialization stringWithObject:payload.asDictionary options:NSJSONWritingPrettyPrinted]);

    [self
     runRequest:putRequest
     succeedWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
     }
     retryWhere:^(UAHTTPRequest *request) {
         if (self.shouldRetryOnConnectionError) {
             NSInteger status = request.response.statusCode;
             return (BOOL)((status >= 500 && status <= 599) || request.error);
         }
         return NO;
     }
     onSuccess:successBlock
     onFailure:failureBlock];
}


- (void)unregisterDeviceToken:(NSString *)deviceToken
                    onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                    onFailure:(UADeviceAPIClientFailureBlock)failureBlock {

    UAHTTPRequest *deleteRequest = [self requestToDeleteDeviceToken:deviceToken];

    UA_LTRACE(@"Unregistering device token %@", deviceToken);

    [self
     runRequest:deleteRequest
     succeedWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(status == 204);
     }
     retryWhere:^(UAHTTPRequest *request) {
         if (self.shouldRetryOnConnectionError) {
             NSInteger status = request.response.statusCode;
             return (BOOL)((status >= 500 && status <= 599) || request.error);
         }
         return NO;
     }
     onSuccess:successBlock
     onFailure:failureBlock];
};


@end
