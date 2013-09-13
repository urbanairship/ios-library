
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
@property(nonatomic, strong) UADeviceRegistrationData *lastSuccessfulRegistration;
@property(nonatomic, strong) UADeviceRegistrationData *pendingRegistration;

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

//we want to avoid sending duplicate payloads, when possible
- (BOOL)shouldSendRegistrationWithData:(UADeviceRegistrationData *)data {
    //if there's already one going out
    if (self.pendingRegistration) {
        //return NO if it's equal to the current data
        return ![self.pendingRegistration isEqual:data];
    } else {
        //otherwise if there was a previous successful registration/unregistration
        if (self.lastSuccessfulRegistration) {
            //return NO if it's equal to the current data
            return ![self.lastSuccessfulRegistration isEqual:data];
        } else {
            return YES;
        }
    }
}

- (void)runRequest:(UAHTTPRequest *)request
          withData:(UADeviceRegistrationData *)registrationData
      succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
        retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
         onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
         onFailure:(UADeviceAPIClientFailureBlock)failureBlock
        forcefully:(BOOL)forcefully {

    //if the forcefully flag is set, we don't care about what we haved cached, otherwise make sure it's not a duplicate
    if (forcefully || [self shouldSendRegistrationWithData:registrationData]) {

        [self.requestEngine cancelAllRequests];

        //synchronize here since we're messing with the registration cache
        //the success/failure blocks below will be triggered on the main thread
        @synchronized(self) {
            self.pendingRegistration = registrationData;
        }

        [self.requestEngine
         runRequest:request
         succeedWhere:succeedWhereBlock
         retryWhere:retryWhereBlock
         onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
             UA_LTRACE(@"DeviceAPI request succeeded: responseData=%@, length=%lu", request.responseString, (unsigned long)[request.responseData length]);

             //clear the pending cache,  update last successful cache
             self.pendingRegistration = nil;
             self.lastSuccessfulRegistration = registrationData;
             if (successBlock) {
                 successBlock();
             } else {
                 UA_LERR(@"missing successBlock");
             }
         }
         onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
             UA_LTRACE(@"DeviceAPI request failed");

             //clear the pending cache
             self.pendingRegistration = nil;
             if (failureBlock) {
                 failureBlock(request);
             } else {
                 UA_LERR(@"missing failureBlock");
             }
         }];
    } else {
        UA_LDEBUG(@"Ignoring duplicate request.");
    }
}

- (void)registerWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock
              forcefully:(BOOL)forcefully {

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
     onFailure:failureBlock
     forcefully:forcefully];
}

- (void)registerWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock {
    [self registerWithData:registrationData onSuccess:successBlock onFailure:failureBlock forcefully:NO];
}

- (void)unregisterWithData:(UADeviceRegistrationData *)registrationData
                 onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                 onFailure:(UADeviceAPIClientFailureBlock)failureBlock
                forcefully:(BOOL)forcefully {

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
     onFailure:failureBlock
     forcefully:forcefully];
};

- (void)unregisterWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock {
    [self unregisterWithData:registrationData onSuccess:successBlock onFailure:failureBlock forcefully:NO];
}


@end
