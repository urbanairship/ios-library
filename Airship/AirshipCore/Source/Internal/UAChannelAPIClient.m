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

NSString * const UAChannelAPIClientErrorDomain = @"com.urbanairship.channel_api_client";

@implementation UAChannelAPIClient

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [UAChannelAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[UAChannelAPIClient alloc] initWithConfig:config session:session];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
               completionHandler:(UAChannelAPIClientCreateCompletionHandler)completionHandler {

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
        NSHTTPURLResponse *httpResponse = [self castResponse:response error:&error];

        if (error) {
            return completionHandler(nil, NO, error);
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 200 && status != 201) {
            UA_LTRACE(@"Channel creation failed with status: %ld error: %@", status, error);

            NSError *error = status == 409 ? [self conflictError] : [self unsuccessfulStatusError];
            return completionHandler(nil, NO, error);
        }

        // Success
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

        UA_LTRACE(@"Channel creation succeeded with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);

        // Parse the response
        NSString *channelID = [jsonResponse valueForKey:@"channel_id"];
        BOOL existing = httpResponse.statusCode == 200;

        completionHandler(channelID, existing, nil);
    }];
}

- (void)updateChannelWithID:(NSString *)channelID
                withPayload:(UAChannelRegistrationPayload *)payload
          completionHandler:(UAChannelAPIClientUpdateCompletionHandler)completionHandler {

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
        NSHTTPURLResponse *httpResponse = [self castResponse:response error:&error];

        if (error) {
            return completionHandler(error);
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 200 && status != 201) {
            UA_LTRACE(@"Channel update failed with status: %ld error: %@", (unsigned long)httpResponse.statusCode, error);
            NSError *error = status == 409 ? [self conflictError] : [self unsuccessfulStatusError];
            return completionHandler(error);
        }

        // Success
        UA_LTRACE(@"Channel update succeeded with status: %ld", (unsigned long)httpResponse.statusCode);
        completionHandler(nil);
    }];
}

- (NSError *)unsuccessfulStatusError {
    NSString *msg = [NSString stringWithFormat:@"Channel client encountered an unsuccessful status"];

    NSError *error = [NSError errorWithDomain:UAChannelAPIClientErrorDomain
                                         code:UAChannelAPIClientErrorUnsuccessfulStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSError *)conflictError {
    NSString *msg = [NSString stringWithFormat:@"Channel client encountered a conflict"];

    NSError *error = [NSError errorWithDomain:UAChannelAPIClientErrorDomain
                                         code:UAChannelAPIClientErrorConflict
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}


@end
