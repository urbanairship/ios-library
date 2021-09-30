/* Copyright Airship and Contributors */

#import <CommonCrypto/CommonHMAC.h>
#import "UAAuthTokenAPIClient+Internal.h"
#import "NSDictionary+UAAdditions+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
#define kUAAuthTokenPath @"/api/auth/device"
#define kUAAuthTokenTokenKey @"token"
#define kUAAuthTokenExpiresKey @"expires_in"

NSString * const UAAuthTokenAPIClientErrorDomain = @"com.urbanairship.auth_token_api_client";

@interface UAAuthTokenResponse()
@property(nonatomic, strong) UAAuthToken *token;
@property(nonatomic, assign) NSUInteger status;

@end

@implementation UAAuthTokenResponse

- (instancetype)initWithStatus:(NSUInteger)status authToken:(UAAuthToken *)token {
    self = [super init];

    if (self) {
        self.status = status;
        self.token = token;
    }
    return self;

}

- (bool)isSuccess {
    return self.status >= 200 && self.status <= 299;
}

- (bool)isClientError  {
    return self.status >= 400 && self.status <= 499;
}

- (bool)isServerError  {
    return self.status >= 500 && self.status <= 599;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAAuthTokenResponse(status=%ld)", self.status];
}


@end

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

    return [[self alloc] initWithConfig:config session:[[UARequestSession alloc] initWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

- (UARequest *)authTokenRequestWithChannelID:(NSString *)channelID {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUAAuthTokenPath];
    NSString *bearerToken = [self createBearerToken:channelID];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.method = @"GET";
        builder.url = [NSURL URLWithString:urlString];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];
        [builder setValue:channelID header:@"X-UA-Channel-ID"];
        [builder setValue:self.config.appKey header:@"X-UA-App-Key"];
        [builder setValue:[@"Bearer " stringByAppendingString:bearerToken] header:@"Authorization"];
    }];

    return request;
}

- (void)tokenWithChannelID:(NSString *)channelID completionHandler:(void (^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))completionHandler {
    UARequest *request = [self authTokenRequestWithChannelID:channelID];

    [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LTRACE(@"Auth token request failed with error %@", error);
            return completionHandler(nil, error);
        }

        NSInteger status = response.statusCode;

        // Unsuccessful HTTP response
        if (!(status >= 200 && status <= 299)) {
            return completionHandler([[UAAuthTokenResponse alloc] initWithStatus:response.statusCode authToken:nil], nil);
        }

        // Successful HTTP response
        UA_LTRACE(@"Auth token request succeeded with status: %lu", (unsigned long)status);

        NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        UAAuthToken *authToken = [self parseAuthToken:responseBody channelID:channelID];

        if (!authToken) {
            return completionHandler(nil, [UAirshipErrors parseError:@"Failed to parse token"]);
        }

        // Successful auth token request
        completionHandler([[UAAuthTokenResponse alloc] initWithStatus:response.statusCode authToken:authToken], nil);
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
