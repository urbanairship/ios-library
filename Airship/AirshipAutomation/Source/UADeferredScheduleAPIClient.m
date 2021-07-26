/* Copyright Airship and Contributors */

#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAStateOverrides+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

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
#define kUADeferredScheduleAPIClientStateOverridesKey @"state_overrides"
#define kUADeferredScheduleAPIClientAppVersionKey @"app_version"
#define kUADeferredScheduleAPIClientSDKVersionKey @"sdk_version"
#define kUADeferredScheduleAPIClientNotificationOptInKey @"notification_opt_in"
#define kUADeferredScheduleAPIClientLocaleLanguageKey @"locale_language"
#define kUADeferredScheduleAPIClientLocaleCountryKey @"locale_country"

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
@property(nonatomic, strong) UADispatcher *requestDispatcher;
@property(nonatomic, copy) UAStateOverrides * (^stateOverridesProvider)(void);
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UADeferredScheduleAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
                    dispatcher:(UADispatcher *)dispatcher
                   authManager:(UAAuthTokenManager *)authManager
        stateOverridesProvider:(nonnull UAStateOverrides * (^)(void))stateOverridesProvider {

    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
        self.authManager = authManager;
        self.requestDispatcher = dispatcher;
        self.stateOverridesProvider = stateOverridesProvider;
    }

    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config authManager:(nonnull UAAuthTokenManager *)authManager {
    return [[self alloc] initWithConfig:config
                                session:[[UARequestSession alloc] initWithConfig:config]
                             dispatcher:UADispatcher.serial
                            authManager:authManager
                 stateOverridesProvider:[self defaultStateOverridesProvider]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
                      dispatcher:(UADispatcher *)dispatcher
                     authManager:(nonnull UAAuthTokenManager *)authManager
          stateOverridesProvider:(nonnull UAStateOverrides * (^)(void))stateOverridesProvider {

    return [[self alloc] initWithConfig:config
                                session:session
                             dispatcher:dispatcher
                            authManager:authManager
                 stateOverridesProvider:stateOverridesProvider];
}

+ (UAStateOverrides * (^)(void))defaultStateOverridesProvider {
    return ^{
        return [UAStateOverrides defaultStateOverrides];
    };;
}

- (void)resolveURL:(NSURL *)URL
         channelID:(NSString *)channelID
    triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
      tagOverrides:(NSArray<UATagGroupUpdate *> *)tagOverrides
attributeOverrides:(NSArray<UAAttributeUpdate *> *)attributeOverrides
 completionHandler:(void (^)(UADeferredScheduleResult * _Nullable, NSError * _Nullable))completionHandler {

    UA_WEAKIFY(self)
    [self.requestDispatcher dispatchAsync:^{
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
    }];
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
    __block NSString *authToken;
    __block UASemaphore *semaphore = [[UASemaphore alloc] init];

    [self.authManager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        authToken = token;
        [semaphore signal];
    }];

    [semaphore wait];

    return authToken;
}

- (UADeferredScheduleAPIClientResponse *)performRequest:(NSString *)authToken
                                                    URL:(NSURL *)URL
                                              channelID:(NSString *)channelID
                                         triggerContext:(UAScheduleTriggerContext *)triggerContext
                                           tagOverrides:(NSArray<UATagGroupUpdate *> *)tagOverrides
                                     attributeOverrides:(NSArray<UAAttributeUpdate *> *)attributeOverrides {

    UARequest *request = [self requestWithAuthToken:authToken
                                                URL:URL
                                          channelID:channelID
                                     triggerContext:triggerContext
                                       tagOverrides:tagOverrides
                                 attributeOverrides:attributeOverrides];

    __block UADeferredScheduleAPIClientResponse *clientResponse;
    __block UASemaphore *semaphore = [[UASemaphore alloc] init];

    [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        clientResponse = [[UADeferredScheduleAPIClientResponse alloc] init];

        if (response) {
            clientResponse.status = response.statusCode;
            clientResponse.body = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }

        clientResponse.error = error;

        [semaphore signal];
    }];

    [semaphore wait];

    return clientResponse;
}


- (NSData *)requestBodyWithChannelID:(NSString *)channelID
                      triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
                        tagOverrides:(NSArray<UATagGroupUpdate *> *)tagOverrides
                  attributeOverrides:(NSArray<UAAttributeUpdate *> *)attributeOverrides {
    
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
        payload[kUADeferredScheduleAPIClientTagOverridesKey] = [self tagPayloadFromUpdates:tagOverrides];
    }
    
    if (attributeOverrides.count) {
        payload[kUADeferredScheduleAPIClientAttributeOverridesKey] = [self attributesPayloadFromUpdates:attributeOverrides];
    }

    UAStateOverrides *stateOverrides = self.stateOverridesProvider();
    NSMutableDictionary *stateOverridesPayload = [NSMutableDictionary dictionary];
    [stateOverridesPayload setValue:stateOverrides.sdkVersion forKey:kUADeferredScheduleAPIClientSDKVersionKey];
    [stateOverridesPayload setValue:stateOverrides.appVersion forKey:kUADeferredScheduleAPIClientAppVersionKey];
    [stateOverridesPayload setValue:stateOverrides.localeCountry forKey:kUADeferredScheduleAPIClientLocaleCountryKey];
    [stateOverridesPayload setValue:stateOverrides.localeLanguage forKey:kUADeferredScheduleAPIClientLocaleLanguageKey];
    [stateOverridesPayload setValue:@(stateOverrides.notificationOptIn) forKey:kUADeferredScheduleAPIClientNotificationOptInKey];

    payload[kUADeferredScheduleAPIClientStateOverridesKey] = stateOverridesPayload;

    return [UAJSONSerialization dataWithJSONObject:payload
                                           options:0
                                             error:nil];
}

- (UARequest *)requestWithAuthToken:(NSString *)authToken
                                URL:(NSURL *)URL
                          channelID:(NSString *)channelID
                     triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
                       tagOverrides:(NSArray<UATagGroupUpdate *> *)tagOverrides
                 attributeOverrides:(NSArray<UAAttributeUpdate *> *)attributeOverrides {

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.method = @"POST";
        builder.url = URL;

        builder.body = [self requestBodyWithChannelID:channelID
                                       triggerContext:triggerContext
                                         tagOverrides:tagOverrides
                                   attributeOverrides:attributeOverrides];

        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];
        [builder setValue:[@"Bearer " stringByAppendingString:authToken] header:@"Authorization"];
    }];

    return request;
}

- (UADeferredScheduleResult *)parseResponseBody:(NSDictionary *)responseBody {
    BOOL audienceMatch = [responseBody numberForKey:kUADeferredScheduleAPIClientAudienceMatchKey defaultValue:@(NO)].boolValue;
    UAInAppMessage *message;

    NSString *responseType = [responseBody stringForKey:kUADeferredScheduleAPIClientResponseTypeKey defaultValue:nil];

    if (audienceMatch && [responseType isEqualToString:kUADeferredScheduleAPIClientInAppMessageType]) {
        NSDictionary *messageJSON = [responseBody dictionaryForKey:kUADeferredScheduleAPIClientMessageKey defaultValue:nil];
        NSError *error;
        message = [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:&error];
        if (error) {
            UA_LDEBUG(@"Unable to create in-app message from response body: %@", responseBody);
        }
    }

    return [UADeferredScheduleResult resultWithMessage:message audienceMatch:audienceMatch];
}

- (id)attributesPayloadFromUpdates:(NSArray<UAAttributeUpdate *> *)updates {
    updates = [UAAudienceUtils collapseAttributeUpdates:updates];
    
    NSMutableArray *payload = [NSMutableArray array];
    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    
    for (UAAttributeUpdate *update in updates) {
        NSMutableDictionary *attributePayload = [NSMutableDictionary dictionary];
        NSString *type = update.type == UAAttributeUpdateTypeSet ? @"set" : @"remove";
        [attributePayload setValue:type forKey:@"action"];
        [attributePayload setValue:update.attribute forKey:@"key"];
        [attributePayload setValue:update.value forKey:@"value"];
        [attributePayload setValue:[formatter stringFromDate:update.date] forKey:@"timestamp"];
        
        [payload addObject:attributePayload];
    }
    
    return payload;
}
    
- (id)tagPayloadFromUpdates:(NSArray<UATagGroupUpdate *> *)updates {
    updates = [UAAudienceUtils collapseTagGroupUpdates:updates];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    NSMutableDictionary *addTags = [NSMutableDictionary dictionary];
    NSMutableDictionary *removeTags = [NSMutableDictionary dictionary];
    NSMutableDictionary *setTags = [NSMutableDictionary dictionary];
    
    for (UATagGroupUpdate *update in updates) {
        switch (update.type) {
            case UATagGroupUpdateTypeAdd:
                addTags[update.group] = update.tags;
                break;

            case UATagGroupUpdateTypeRemove:
                removeTags[update.group] = update.tags;
                break;
                
            case UATagGroupUpdateTypeSet:
                setTags[update.group] = update.tags;
                break;
        }
    }
    
    if (addTags.count) {
        payload[@"add"] = addTags;
    }
    
    if (removeTags.count) {
        payload[@"remove"] = removeTags;
    }
    
    if (setTags.count) {
        payload[@"set"] = setTags;
    }
    
    return payload;
}

@end
