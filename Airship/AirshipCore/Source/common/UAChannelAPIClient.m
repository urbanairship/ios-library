/* Copyright Airship and Contributors */

#import "UAChannelAPIClient+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"

#define kUAChannelAPIPath @"/api/channels/"

@implementation UAChannelAPIClient

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [UAChannelAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[UAChannelAPIClient alloc] initWithConfig:config session:session];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                      onSuccess:(UAChannelAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    UA_LTRACE(@"Creating channel with: %@.", payload);

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUAChannelAPIPath];
        builder.URL = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = [payload asJSONData];
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
            UA_LTRACE(@"Channel creation failed with status: %ld error: %@", (unsigned long)httpResponse.statusCode, error);
            failureBlock(httpResponse.statusCode);
            return;
        }

        // Success
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

        UA_LTRACE(@"Channel creation succeeded with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);

        // Parse the response
        NSString *channelID = [jsonResponse valueForKey:@"channel_id"];
        BOOL existing = httpResponse.statusCode == 200;

        successBlock(channelID, existing);
    }];
}

- (void)updateChannelWithID:(NSString *)channelID
                withPayload:(UAChannelRegistrationPayload *)payload
                  onSuccess:(UAChannelAPIClientUpdateSuccessBlock)successBlock
                  onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    UA_LTRACE(@"Updating channel with: %@.", payload);
    
    NSString *channelLocation = [NSString stringWithFormat:@"%@%@%@", self.config.deviceAPIURL, kUAChannelAPIPath, channelID];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.URL = [NSURL URLWithString:channelLocation];
        builder.method = @"PUT";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = [payload asJSONData];
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
