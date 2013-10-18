
#import "UADeviceAPIClient.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAHTTPConnectionOperation.h"
#import "NSJSONSerialization+UAAdditions.h"

#define kUAPushRetryTimeInitialDelay 60
#define kUAPushRetryTimeMultiplier 2
#define kUAPushRetryTimeMaxDelay 300
#define kUAPushDeviceTokensURLBase @"/api/device_tokens/"


@interface UADeviceAPIClient()
@property(nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@end

@implementation UADeviceAPIClient

- (id)init {
    self = [super init];
    if (self) {
        self.shouldRetryOnConnectionError = YES;
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUAPushRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUAPushRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUAPushRetryTimeMultiplier;
    }
    return self;
}

- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

- (NSString *)deviceTokenURLStringWithRegistrationData:(UADeviceRegistrationData *)registrationData {
    return [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].config.deviceAPIURL, kUAPushDeviceTokensURLBase, registrationData.deviceToken];
}

- (UAHTTPRequest *)requestToRegisterDeviceTokenWithData:(UADeviceRegistrationData *)registrationData {
    NSString *urlString = [self deviceTokenURLStringWithRegistrationData:registrationData];
    NSURL *url = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:url method:@"PUT"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    if (registrationData.payload != nil) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        [request appendBodyData:[registrationData.payload asJSONData]];
    }
    return request;
}

- (UAHTTPRequest *)requestToDeleteDeviceTokenWithData:(UADeviceRegistrationData *)registrationData {
    NSString *urlString = [self deviceTokenURLStringWithRegistrationData:registrationData];
    NSURL *url = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:url method:@"DELETE"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    return request;
}

- (void)runRequest:(UAHTTPRequest *)request
          withData:(UADeviceRegistrationData *)registrationData
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
         UA_LTRACE(@"DeviceAPI request failed");

         //clear the pending cache
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)registerWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock {

    UAHTTPRequest *putRequest = [self requestToRegisterDeviceTokenWithData:registrationData];

    UA_LDEBUG(@"Running device registration.");
    UA_LTRACE(@"Sending device registration with headers: %@, payload: %@",
              [putRequest.headers descriptionWithLocale:nil indent:1],
              [NSJSONSerialization stringWithObject:registrationData.payload.asDictionary options:NSJSONWritingPrettyPrinted]);

    [self
     runRequest:putRequest withData:registrationData
     succeedWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
     }
     retryWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(((status >= 500 && status <= 599)|| request.error) && self.shouldRetryOnConnectionError);
     }
     onSuccess:successBlock
     onFailure:failureBlock];
}


- (void)unregisterWithData:(UADeviceRegistrationData *)registrationData
                 onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                 onFailure:(UADeviceAPIClientFailureBlock)failureBlock {

    UAHTTPRequest *deleteRequest = [self requestToDeleteDeviceTokenWithData:registrationData];

    UA_LDEBUG(@"Running device unregistration.");
    UA_LTRACE(@"Sending device unregistration with headers: %@, payload: %@",
              [deleteRequest.headers descriptionWithLocale:nil indent:1],
              [NSJSONSerialization stringWithObject:registrationData.payload.asDictionary options:NSJSONWritingPrettyPrinted]);

    [self
     runRequest:deleteRequest withData:registrationData
     succeedWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(status == 204);
     }
     retryWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(((status >= 500 && status <= 599) || request.error) && self.shouldRetryOnConnectionError);
     }
     onSuccess:successBlock
     onFailure:failureBlock];
};


@end
