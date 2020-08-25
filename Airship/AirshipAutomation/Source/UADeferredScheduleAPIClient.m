/* Copyright Airship and Contributors */

#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAJSONSerialization.h"
#import "UAScheduleTrigger+Internal.h"
#import "NSDictionary+UAAdditions.h"
#import "UAInAppMessage+Internal.h"

#define kUADeferredScheduleAPIClientPlatformKey @"platform"
#define kUADeferredScheduleAPIClientChannelIDKey @"channel_id"
#define kUADeferredScheduleAPIClientPlatformiOS @"ios"
#define kUADeferredScheduleAPIClientTriggerKey @"trigger"
#define kUADeferredScheduleAPIClientTriggerTypeKey @"type"
#define kUADeferredScheduleAPIClientTriggerGoalKey @"goal"
#define kUADeferredScheduleAPIClientTriggerEventKey @"event"
#define kUADeferredScheduleAPIClientTagOverridesKey @"tag_overrides"
#define kUADeferredScheduleAPIClientAttributeOverridesKey @"attribute_overrides"
#define kUADeferredScheduleAPIClientAudienceMatchKey @"audience_match"
#define kUADeferredScheduleAPIClientResponseTypeKey @"type"
#define kUADeferredScheduleAPIClientMessageKey @"message"
#define kUADeferredScheduleAPIClientInAppMessageType @"in_app_message"

NSString * const UADeferredScheduleAPIClientErrorDomain = @"com.urbanairship.deferred_api_client";

@interface UADeferredScheduleAPIClientResponse : NSObject
@property (nonatomic, copy, nullable) NSDictionary *body;
@property (nonatomic, strong, nullable) NSError *error;
@property (nonatomic, assign) NSUInteger status;
@end

@implementation UADeferredScheduleAPIClientResponse
@end

@interface UADeferredScheduleAPIClient ()
@property(nonatomic, strong) UAAuthTokenManager *authManager;
@property(nonatomic, strong) dispatch_queue_t requestQueue;
@end

@implementation UADeferredScheduleAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
                   authManager:(UAAuthTokenManager *)authManager {

    self = [super initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session];

    if (self) {
        self.authManager = authManager;
        self.requestQueue = dispatch_queue_create("com.urbanairship.deferred_schedule_api_client.request_queue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config authManager:(nonnull UAAuthTokenManager *)authManager {
    return [[self alloc] initWithConfig:config
                                session:[UARequestSession sessionWithConfig:config]
                            authManager:authManager];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
                     authManager:(nonnull UAAuthTokenManager *)authManager {
    return [[self alloc] initWithConfig:config session:session authManager:authManager];
}

- (void)resolveURL:(NSURL *)URL
         channelID:(NSString *)channelID
    triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      tagOverrides:(NSArray<UATagGroupsMutation *> *)tagOverrides
attributeOverrides:(UAAttributePendingMutations *)attributeOverrides
 completionHandler:(void (^)(UADeferredScheduleResult * _Nullable, NSError * _Nullable))completionHandler {

    UA_WEAKIFY(self)
    dispatch_async(self.requestQueue, ^{
        UA_STRONGIFY(self)
        NSString *token = [self authToken];

        if (!token) {
            return completionHandler(nil, [self missingAuthTokenError]);
        }

        UADeferredScheduleAPIClientResponse *response = [self performRequest:token
                                                                         URL:URL
                                                                   channelID:channelID
                                                              triggerContext:triggerContext
                                                                tagOverrides:tagOverrides
                                                          attributeOverrides:attributeOverrides];

        if (response.error) {
            UA_LTRACE(@"Deferred schedule request failed with error %@", response.error);
            return completionHandler(nil, [self timeoutError]);
        }

        // If unauthorized, manually expire the token and try again.
        if (response.status == 401){
            [self.authManager expireToken:token];

            token = [self authToken];

            if (!token) {
                return completionHandler(nil, [self missingAuthTokenError]);
            }

            response = [self performRequest:token
                                        URL:URL
                                  channelID:channelID
                             triggerContext:triggerContext
                               tagOverrides:tagOverrides
                         attributeOverrides:attributeOverrides];

            if (response.error) {
                UA_LTRACE(@"Deferred schedule request failed with error %@", response.error);
                return completionHandler(nil, [self timeoutError]);
            }
        }

        // Unsuccessful HTTP response
        if (!(response.status >= 200 && response.status <= 299)) {
            UA_LTRACE(@"Deferred schedule request failed with status: %lu", (unsigned long)response.status);
            return completionHandler(nil, [self unsuccessfulStatusError]);
        }

        // Successful HTTP response
        UA_LTRACE(@"Deferred schedule request succeeded with status: %lu", (unsigned long)response.status);

        UADeferredScheduleResult *result = [self parseResponseBody:response.body];

        // Successful deferred schedule request
        completionHandler(result, nil);
    });
}

- (NSError *)missingAuthTokenError {
    NSString *msg = [NSString stringWithFormat:@"Unable to retrieve auth token"];

    NSError *error = [NSError errorWithDomain:UADeferredScheduleAPIClientErrorDomain
                                         code:UADeferredScheduleAPIClientErrorMissingAuthToken
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSError *)timeoutError {
    NSString *msg = [NSString stringWithFormat:@"Deferred schedule client timed out"];

    NSError *error = [NSError errorWithDomain:UADeferredScheduleAPIClientErrorDomain
                                         code:UADeferredScheduleAPIClientErrorTimedOut
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSError *)unsuccessfulStatusError {
    NSString *msg = [NSString stringWithFormat:@"Deferred schedule client encountered an unsuccessful status"];

    NSError *error = [NSError errorWithDomain:UADeferredScheduleAPIClientErrorDomain
                                         code:UADeferredScheduleAPIClientErrorUnsuccessfulStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSString *)authToken {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block NSString *authToken;
    [self.authManager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        authToken = token;
        dispatch_semaphore_signal(semaphore);
    }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return authToken;
}

- (UADeferredScheduleAPIClientResponse *)performRequest:(NSString *)authToken
                                                    URL:(NSURL *)URL
                                              channelID:(NSString *)channelID
                                         triggerContext:(UAScheduleTriggerContext *)triggerContext
                                           tagOverrides:(NSArray<UATagGroupsMutation *> *)tagOverrides
                                     attributeOverrides:(UAAttributePendingMutations *)attributeOverrides {

    UARequest *request = [self requestWithAuthToken:authToken
                                                URL:URL
                                          channelID:channelID
                                     triggerContext:triggerContext
                                       tagOverrides:tagOverrides
                                 attributeOverrides:attributeOverrides];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block UADeferredScheduleAPIClientResponse *clientResponse;

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse;

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        clientResponse = [[UADeferredScheduleAPIClientResponse alloc] init];
        if (httpResponse) {
            clientResponse.status = httpResponse.statusCode;
            clientResponse.body = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }

        clientResponse.error = error;

        dispatch_semaphore_signal(semaphore);
    }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return clientResponse;
}


- (NSData *)requestBodyWithChannelID:(NSString *)channelID
                      triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
                        tagOverrides:(NSArray<UATagGroupsMutation *> *)tagOverrides
                  attributeOverrides:(UAAttributePendingMutations *)attributeOverrides {

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload addEntriesFromDictionary:@{kUADeferredScheduleAPIClientPlatformKey: kUADeferredScheduleAPIClientPlatformiOS,
                                        kUADeferredScheduleAPIClientChannelIDKey: channelID}];

    if (triggerContext) {
        NSMutableDictionary *triggerContextPayload = [NSMutableDictionary dictionary];
        [triggerContextPayload setValue:triggerContext.trigger.typeName forKey:kUADeferredScheduleAPIClientTriggerTypeKey];
        [triggerContextPayload setValue:triggerContext.trigger.goal forKey:kUADeferredScheduleAPIClientTriggerGoalKey];
        [triggerContextPayload setValue:triggerContext.event forKey:kUADeferredScheduleAPIClientTriggerEventKey];
        payload[kUADeferredScheduleAPIClientTriggerKey] = triggerContextPayload;
    }

    if (tagOverrides.count) {
        NSMutableArray *overrides = [NSMutableArray array];

        for (UATagGroupsMutation *mutation in tagOverrides) {
            [overrides addObject:[mutation payload]];
        }

        payload[kUADeferredScheduleAPIClientTagOverridesKey] = overrides;
    }

    NSArray<NSDictionary *>* attributeMutationsPayload = attributeOverrides.mutationsPayload;

    if (attributeMutationsPayload.count) {
        payload[kUADeferredScheduleAPIClientAttributeOverridesKey] = attributeMutationsPayload;
    }

    return [UAJSONSerialization dataWithJSONObject:payload
                                           options:0
                                             error:nil];
}

- (UARequest *)requestWithAuthToken:(NSString *)authToken
                                URL:(NSURL *)URL
                          channelID:(NSString *)channelID
                     triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
                       tagOverrides:(NSArray<UATagGroupsMutation *> *)tagOverrides
                 attributeOverrides:(UAAttributePendingMutations *)attributeOverrides {

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.method = @"POST";
        builder.URL = URL;

        builder.body = [self requestBodyWithChannelID:channelID
                                       triggerContext:triggerContext
                                         tagOverrides:tagOverrides
                                   attributeOverrides:attributeOverrides];

        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:[@"Bearer " stringByAppendingString:authToken] forHeader:@"Authorization"];
    }];

    return request;
}

- (UADeferredScheduleResult *)parseResponseBody:(NSDictionary *)responseBody {
    BOOL audienceMatch = [responseBody numberForKey:kUADeferredScheduleAPIClientAudienceMatchKey defaultValue:@(NO)].boolValue;
    UAInAppMessage *message;

    NSString *responseType = [responseBody stringForKey:kUADeferredScheduleAPIClientResponseTypeKey defaultValue:nil];

    if ([responseType isEqualToString:kUADeferredScheduleAPIClientInAppMessageType]) {
        NSDictionary *messageJSON = [responseBody dictionaryForKey:kUADeferredScheduleAPIClientMessageKey defaultValue:nil];
        NSError *error;
        message = [UAInAppMessage messageWithJSON:messageJSON error:&error];
        if (error) {
            UA_LDEBUG(@"Unable to create in-app message from response body: %@", responseBody);
        }
    }

    return [UADeferredScheduleResult resultWithMessage:message audienceMatch:audienceMatch];
}

@end
