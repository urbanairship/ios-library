/* Copyright Airship and Contributors */

#import "UAAttributeAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAAPIClient.h"

NSString *const UAChannelsAPIPath = @"/api/channels/";
NSString *const UAAttributePlatformSpecifier = @"/attributes?platform=";
NSString *const UAAttributePlatform = @"ios";

NSString *const UANamedUserAPIPath = @"/api/named_users/";
NSString *const UAAttributeSpecifier = @"/attributes";

@implementation UAAttributeAPIClient

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [UAAttributeAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[UAAttributeAPIClient alloc] initWithConfig:config session:session];
}

- (void)updateChannel:(NSString *)identifier withAttributePayload:(NSDictionary *)payload
                                                        onSuccess:(UAAttributeAPIClientSuccessBlock)successBlock
                                                        onFailure:(UAAttributeAPIClientFailureBlock)failureBlock {
    UA_LTRACE(@"Updating channel: %@ with attribute payload: %@.", identifier, payload);

    // /api/channels/<channel id>/attributes?platform=<platform>
    NSString *attributeEndpoint = [NSString stringWithFormat:@"%@%@%@%@%@", self.config.deviceAPIURL, UAChannelsAPIPath, identifier, UAAttributePlatformSpecifier, UAAttributePlatform];

    [self updateEndpoint:attributeEndpoint WithAttributePayload:payload onSuccess:successBlock onFailure:failureBlock];
}

- (void)updateNamedUser:(NSString *)identifier withAttributePayload:(NSDictionary *)payload
              onSuccess:(UAAttributeAPIClientSuccessBlock)successBlock
              onFailure:(UAAttributeAPIClientFailureBlock)failureBlock {
    UA_LTRACE(@"Updating nameduser: %@ with attribute payload: %@.", identifier, payload);

    // /api/named_users/<named_user_id>/attributes
    NSString *attributeEndpoint =  [NSString stringWithFormat:@"%@%@%@%@", self.config.deviceAPIURL, UANamedUserAPIPath, identifier, UAAttributeSpecifier];

    [self updateEndpoint:attributeEndpoint WithAttributePayload:payload onSuccess:successBlock onFailure:failureBlock];
}

- (void)updateEndpoint:(NSString *)attributeEndpoint WithAttributePayload:(NSDictionary *)payload
                         onSuccess:(UAAttributeAPIClientSuccessBlock)successBlock
                         onFailure:(UAAttributeAPIClientFailureBlock)failureBlock {
    if (!self.enabled) {
        UA_LDEBUG(@"Disabled");
        return;
    }

    NSData *payloadData = [UAJSONSerialization dataWithJSONObject:payload
                                                          options:0
                                                            error:nil];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.URL = [NSURL URLWithString:attributeEndpoint];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = payloadData;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
    }];

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData *data, NSURLResponse *response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        // Failure
        if (httpResponse.statusCode != 200 && httpResponse.statusCode != 201) {
            UA_LTRACE(@"Update of %@ failed with status: %ld error: %@", httpResponse.URL, (unsigned long)httpResponse.statusCode, error);
            failureBlock(httpResponse.statusCode);
            return;
        }

        // Success
        UA_LTRACE(@"Update of %@ succeeded with status: %ld", httpResponse.URL, (unsigned long)httpResponse.statusCode);
        successBlock();
    }];
}

@end
