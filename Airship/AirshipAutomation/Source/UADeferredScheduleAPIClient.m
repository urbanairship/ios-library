/* Copyright Airship and Contributors */

#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAStateOverrides+Internal.h"
#import "NSDictionary+UAAdditions+Internal.h"
#import "UADeferredScheduleRetryRules+Internal.h"
#import "UADeferredAPIClientResponse+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
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


@interface UADeferredScheduleAPIClientResponse : NSObject
@property (nonatomic, copy, nullable) NSDictionary *body;
@property (nonatomic, copy, nullable) NSDictionary *headers;
@property (nonatomic, strong, nullable) NSError *error;
@property (nonatomic, assign) NSUInteger status;
@end

@implementation UADeferredScheduleAPIClientResponse
@end

@interface UADeferredScheduleAPIClient ()
@property(nonatomic, copy) UAStateOverrides * (^stateOverridesProvider)(void);
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UADeferredScheduleAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
        stateOverridesProvider:(nonnull UAStateOverrides * (^)(void))stateOverridesProvider {

    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
        self.stateOverridesProvider = stateOverridesProvider;
    }

    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithConfig:config
                                session:[[UARequestSession alloc] initWithConfig:config]
                 stateOverridesProvider:[self defaultStateOverridesProvider]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
          stateOverridesProvider:(nonnull UAStateOverrides * (^)(void))stateOverridesProvider {

    return [[self alloc] initWithConfig:config
                                session:session
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
 audienceOverrides:(UAAutomationAudienceOverrides *)audienceOverrides
 completionHandler:(void (^)(UADeferredAPIClientResponse * _Nullable, NSError * _Nullable))completionHandler {

    NSDictionary *headers = @{@"Accept": @"application/vnd.urbanairship+json; version=3;"};
    NSData *body = [self requestBodyWithChannelID:channelID
                                   triggerContext:triggerContext
                                audienceOverrides:audienceOverrides];

    UARequest *request = [UARequest makeChannelAuthRequestWithChannelID:channelID
                                                                 method:@"POST"
                                                                    url:URL
                                                                headers:headers
                                                                   body:body];

    [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

        UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:nil rules:nil];

        if (error) {
            UA_LTRACE(@"Deferred schedule request failed with error %@", error);
            return completionHandler(clientResponse, error);
        }

        [self handleResponse:response data:data completionHandler:completionHandler];
    }];
}

- (void)handleResponse:(NSHTTPURLResponse * _Nullable)response data:(NSData * _Nullable)data completionHandler:(void (^)(UADeferredAPIClientResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    if (response.statusCode == 409) {
        UA_LTRACE(@"Deferred schedule request failed with status: %lu", (unsigned long)response.statusCode);
        UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:nil rules:nil];
        return completionHandler(clientResponse, nil);
    }
    
    if (response.statusCode == 307 || response.statusCode == 429) {
        UA_LTRACE(@"Deferred schedule request failed with status: %lu", (unsigned long)response.statusCode);
        if (response.allHeaderFields) {
            NSString *location = response.allHeaderFields[@"Location"] ?: nil;
            NSTimeInterval retryTime = response.allHeaderFields[@"Retry-After"] ? [response.allHeaderFields[@"Retry-After"] doubleValue] : 0;
            
            UADeferredScheduleRetryRules *rules = [UADeferredScheduleRetryRules rulesWithLocation:location retryTime:retryTime];
            
            UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:nil rules:rules];
            return completionHandler(clientResponse, nil);
        } else {
            UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:nil rules:nil];
            return completionHandler(clientResponse, nil);
        }
    }

    // Unsuccessful HTTP response
    if (!(response.statusCode >= 200 && response.statusCode <= 299)) {
        UA_LTRACE(@"Deferred schedule request failed with status: %lu", (unsigned long)response.statusCode);
        UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:nil rules:nil];
        return completionHandler(clientResponse, nil);
    }

    // Successful HTTP response
    UA_LTRACE(@"Deferred schedule request succeeded with status: %lu", (unsigned long)response.statusCode);

    UADeferredScheduleResult *result = [self parseResponseBody:[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil]];
    
    UADeferredAPIClientResponse *clientResponse = [UADeferredAPIClientResponse responseWithStatus:response.statusCode result:result rules:nil];
    
    // Successful deferred schedule request
    completionHandler(clientResponse, nil);
    
}

- (NSData *)requestBodyWithChannelID:(NSString *)channelID
                      triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
                   audienceOverrides:(UAAutomationAudienceOverrides *)audienceOverrides {

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

    if (audienceOverrides.tagsPayload.count) {
        payload[kUADeferredScheduleAPIClientTagOverridesKey] = audienceOverrides.tagsPayload;
    }

    if (audienceOverrides.attributesPayload.count) {
        payload[kUADeferredScheduleAPIClientAttributeOverridesKey] = audienceOverrides.attributesPayload;
    }

    UAStateOverrides *stateOverrides = self.stateOverridesProvider();
    NSMutableDictionary *stateOverridesPayload = [NSMutableDictionary dictionary];
    [stateOverridesPayload setValue:stateOverrides.sdkVersion forKey:kUADeferredScheduleAPIClientSDKVersionKey];
    [stateOverridesPayload setValue:stateOverrides.appVersion forKey:kUADeferredScheduleAPIClientAppVersionKey];
    [stateOverridesPayload setValue:stateOverrides.localeCountry forKey:kUADeferredScheduleAPIClientLocaleCountryKey];
    [stateOverridesPayload setValue:stateOverrides.localeLanguage forKey:kUADeferredScheduleAPIClientLocaleLanguageKey];
    [stateOverridesPayload setValue:@(stateOverrides.notificationOptIn) forKey:kUADeferredScheduleAPIClientNotificationOptInKey];

    payload[kUADeferredScheduleAPIClientStateOverridesKey] = stateOverridesPayload;

    return [UAJSONUtils dataWithObject:payload
                                           options:0
                                             error:nil];
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

@end
