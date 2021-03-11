/* Copyright Airship and Contributors */

#import "UAChannelAPIClient+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSError+UAAdditions.h"

#define kUAChannelAPIPath @"/api/channels/"


@interface UAChannelCreateResponse()
@property(nonatomic, copy) NSString *channelID;
@end

@implementation UAChannelCreateResponse

- (instancetype)initWithStatus:(NSUInteger)status channelID:(NSString *)channelID {
    self = [super initWithStatus:status];
    if (self) {
        self.channelID = channelID;
    }
    return self;
}
@end

@interface UAChannelAPIClient()
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UAChannelAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    self = [super init];
    if (self) {
        self.config = config;
        self.session = session;
    }
    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

- (UADisposable *)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
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

    return [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {

        UA_LTRACE(@"Channel creation finished with response: %@ error: %@", response, error);

        if (error) {
            return completionHandler(nil, error);
        }

        NSUInteger status = response.statusCode;
        if (status == 200 || status == 201) {
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

            // Parse the response
            NSString *channelID = [jsonResponse valueForKey:@"channel_id"];

            if (!channelID) {
                NSString *errorMessage = [NSString stringWithFormat:@"Failed to parse channel: %@", error];
                completionHandler(nil, [NSError airshipParseErrorWithMessage:errorMessage]);
            } else {
                completionHandler([[UAChannelCreateResponse alloc] initWithStatus:status channelID:channelID], nil);
            }
        } else {
            completionHandler([[UAChannelCreateResponse alloc] initWithStatus:status], nil);
        }
    }];
}

- (UADisposable *)updateChannelWithID:(NSString *)channelID
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

    return [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {

        UA_LTRACE(@"Channel update finished with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
        } else {
            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}

@end
