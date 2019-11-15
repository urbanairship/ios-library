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
    UA_LTRACE(@"Updating channel:%@ with attribute payload:%@.", identifier, payload);

    if (!self.enabled) {
        UA_LDEBUG(@"Disabled");
        return;
    }

    // /api/channels/<channel id>/attributes?platform=<platform>
    NSString *attributeEndpoint = [NSString stringWithFormat:@"%@%@%@%@%@", self.config.deviceAPIURL, UAChannelsAPIPath, identifier, UAAttributePlatformSpecifier, UAAttributePlatform];

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
            UA_LTRACE(@"Channel update failed with status: %ld error: %@", (unsigned long)httpResponse.statusCode, error);
            failureBlock(httpResponse.statusCode);
            return;
        }

        // Success
        UA_LTRACE(@"Channel update succeeded with status: %ld", (unsigned long)httpResponse.statusCode);
        successBlock();
    }];
}

@end
