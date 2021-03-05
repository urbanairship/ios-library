/* Copyright Airship and Contributors */

#import <CommonCrypto/CommonHMAC.h>

#import "UAAuthTokenAPIClient+Internal.h"

#define kUAAuthTokenPath @"/api/auth/device"
#define kUAAuthTokenTokenKey @"token"
#define kUAAuthTokenExpiresKey @"expires_in"

NSString * const UAAuthTokenAPIClientErrorDomain = @"com.urbanairship.auth_token_api_client";

@interface UAAuthTokenAPIClient()
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UAAuthTokenAPIClient

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

- (UARequest *)authTokenRequestWithChannelID:(NSString *)channelID {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUAAuthTokenPath];
    NSString *bearerToken = [self createBearerToken:channelID];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.method = @"GET";
        builder.URL = [NSURL URLWithString:urlString];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:channelID forHeader:@"X-UA-Channel-ID"];
        [builder setValue:self.config.appKey forHeader:@"X-UA-App-Key"];
        [builder setValue:[@"Bearer " stringByAppendingString:bearerToken] forHeader:@"Authorization"];
    }];

    return request;
}

- (void)tokenWithChannelID:(NSString *)channelID completionHandler:(void (^)(UAAuthToken * _Nullable, NSError * _Nullable))completionHandler {
    UARequest *request = [self authTokenRequestWithChannelID:channelID];

    [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LTRACE(@"Auth token request failed with error %@", error);
            return completionHandler(nil, error);
        }

        NSInteger status = response.statusCode;

        // Unsuccessful HTTP response
        if (!(status >= 200 && status <= 299)) {
            UA_LTRACE(@"Auth token request failed with status: %lu", (unsigned long)status);
            NSString *msg = [NSString stringWithFormat:@"Auth token API client encountered an unsuccessful status"];

            NSError *error = [NSError errorWithDomain:UAAuthTokenAPIClientErrorDomain
                                                 code:UAAuthTokenAPIClientErrorUnsuccessfulStatus
                                             userInfo:@{NSLocalizedDescriptionKey:msg}];

            return completionHandler(nil, error);
        }

        // Successful HTTP response
        UA_LTRACE(@"Auth token request succeeded with status: %lu", (unsigned long)status);

        NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        UAAuthToken *authToken = [self parseAuthToken:responseBody channelID:channelID];

        if (!authToken) {
            NSString *msg = [NSString stringWithFormat:@"Unable to create auth token"];

            NSError *error = [NSError errorWithDomain:UAAuthTokenAPIClientErrorDomain
                                                 code:UAAuthTokenAPIClientErrorInvalidResponse
                                             userInfo:@{NSLocalizedDescriptionKey:msg}];

            return completionHandler(nil, error);
        }

        // Successful auth token request
        completionHandler(authToken, nil);
    }];
}

- (NSString *)createBearerToken:(NSString *)channelID {
    NSData *secret = [self.config.appSecret dataUsingEncoding:NSUTF8StringEncoding];
    NSData *message = [[NSString stringWithFormat:@"%@:%@", self.config.appKey, channelID] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData* hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, secret.bytes, secret.length, message.bytes, message.length, hash.mutableBytes);
    return [hash base64EncodedStringWithOptions:0];
}

- (UAAuthToken *)parseAuthToken:(NSDictionary *)responseBody channelID:channelID {
    NSNumber *expiration = [responseBody numberForKey:kUAAuthTokenExpiresKey defaultValue:nil];
    NSString *token = [responseBody stringForKey:kUAAuthTokenTokenKey defaultValue:nil];

    if (!expiration) {
        UA_LDEBUG(@"Invalid auth token expiration: %@", responseBody);
        return nil;
    }

    if (!token) {
        UA_LDEBUG(@"Missing or invalid auth token in response: %@", responseBody);
        return nil;
    }

    NSDate *expirationDate = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)expiration unsignedLongValue]];

    return [UAAuthToken authTokenWithChannelID:channelID token:token expiration:expirationDate];
}

@end
