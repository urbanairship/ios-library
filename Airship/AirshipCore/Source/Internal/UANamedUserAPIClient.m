/* Copyright Airship and Contributors */

#import "UANamedUserAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization.h"

#define kUANamedUserPath @"/api/named_users"
#define kUANamedUserChannelIDKey @"channel_id"
#define kUANamedUserDeviceTypeKey @"device_type"
#define kUANamedUserIdentifierKey @"named_user_id"

@interface UANamedUserAPIClient()

@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;

@end

@implementation UANamedUserAPIClient

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

- (UADisposable *)associate:(nonnull NSString *)identifier
                  channelID:(nonnull NSString *)channelID
          completionHandler:(void (^)(UAHTTPResponse * _Nullable, NSError * _Nullable))completionHandler {
    UA_LTRACE(@"Associating channel %@ with named user ID: %@", channelID, identifier);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];
    [payload setValue:identifier forKey:kUANamedUserIdentifierKey];

    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUANamedUserPath];
    UARequest *request = [self requestWithPayload:payload
                                        urlString:[NSString stringWithFormat:@"%@%@", urlString, @"/associate"]];

    return [self.session performHTTPRequest:request
                          completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

        UA_LTRACE(@"Associated named user with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
        } else {
            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}


- (UADisposable *)disassociate:(nonnull NSString *)channelID
             completionHandler:(void (^)(UAHTTPResponse * _Nullable, NSError * _Nullable))completionHandler {
    UA_LTRACE(@"Disassociating channel %@ from named user ID", channelID);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];

    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUANamedUserPath];
    UARequest *request = [self requestWithPayload:payload
                                        urlString:[NSString stringWithFormat:@"%@%@", urlString, @"/disassociate"]];

    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        UA_LTRACE(@"Disassociated named user with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
        } else {
            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}

- (UARequest *)requestWithPayload:(NSDictionary *)payload urlString:(NSString *)urlString {

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.method = @"POST";
        builder.URL = [NSURL URLWithString:urlString];
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        builder.body = [UAJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];
    }];

    return request;
}

@end



