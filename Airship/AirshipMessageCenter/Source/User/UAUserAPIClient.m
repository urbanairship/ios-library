/* Copyright Airship and Contributors */

#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"

NSString * const UAUserAPIClientErrorDomain = @"com.urbanairship.user_api_client";

@interface UAUserAPIClient()
@property(nonatomic, strong) UAConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UAUserAPIClient

- (instancetype)initWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        self.config = config;
    }
    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [UAUserAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

- (UADisposable *)createUserWithChannelID:(NSString *)channelID
                        completionHandler:(void (^)(UAUserData * _Nullable data, NSError * _Nullable error))completionHandler {

    NSDictionary *requestBody =  @{
        @"ios_channels": @[channelID]
    };

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *createURLString = [NSString stringWithFormat:@"%@%@",
                                     self.config.deviceAPIURL,
                                     @"/api/user/"];

        builder.URL = [NSURL URLWithString:createURLString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [UAJSONSerialization dataWithJSONObject:requestBody
                                                       options:0
                                                         error:nil];
    }];

    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (response.statusCode == 201 || response.statusCode == 200) {
            UAUserData *userData = [UAUserAPIClient parseResponseData:data error:&error];
            completionHandler(userData, error);
        } else {
            NSError *apiError = [UAUserAPIClient errorFromResponse:response error:error];
            completionHandler(nil, apiError);
        }
    }];
}

- (UADisposable *)updateUserWithData:(UAUserData *)userData
                           channelID:(NSString *)channelID
                   completionHandler:(void (^)(NSError * _Nullable error))completionHandler {

    NSDictionary *requestBody =  @{
        @"ios_channels": @{
                @"add": @[channelID]
        }
    };

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *updateURLString = [NSString stringWithFormat:@"%@%@%@/",
                                     self.config.deviceAPIURL,
                                     @"/api/user/",
                                     userData.username];

        builder.URL = [NSURL URLWithString:updateURLString];
        builder.method = @"POST";
        builder.username = userData.username;
        builder.password = userData.password;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [UAJSONSerialization dataWithJSONObject:requestBody
                                                       options:0
                                                         error:nil];
    }];

    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

        if (response.statusCode == 200 || response.statusCode == 201) {
            completionHandler(nil);
        } else {
            NSError *apiError = [UAUserAPIClient errorFromResponse:response error:error];
            completionHandler(apiError);
        }
    }];
}

+ (NSError *)errorFromResponse:(NSHTTPURLResponse *)response error:(NSError *)error {
    NSString *msg = [NSString stringWithFormat:@"User API failed with status %ld error: %@", response.statusCode, error];

    if (error || [response hasRetriableStatus]) {
        return [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                   code:UAUserAPIClientErrorRecoverable
                               userInfo:@{NSLocalizedDescriptionKey:msg}];
    } else {
        return [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                   code:UAUserAPIClientErrorUnrecoverable
                               userInfo:@{NSLocalizedDescriptionKey:msg}];
    }
}


+ (UAUserData *)parseResponseData:(NSData *)data error:(NSError **)error {
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSString *username = [jsonResponse objectForKey:@"user_id"];
    NSString *password = [jsonResponse objectForKey:@"password"];

    if (!username || !password) {
        NSString *msg = [NSString stringWithFormat:@"User API failed. Unable to parse response %@", jsonResponse];
        *error = [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                                 code:UAUserAPIClientErrorUnrecoverable
                                             userInfo:@{NSLocalizedDescriptionKey:msg}];
        return nil;
    }


    return [UAUserData dataWithUsername:username password:password];
}


@end
