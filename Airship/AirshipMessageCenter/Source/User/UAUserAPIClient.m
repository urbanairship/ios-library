/* Copyright Airship and Contributors */

#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAUserCreateResponse()
@property(nonatomic, strong) UAUserData *userData;
@property(nonatomic, assign) NSUInteger status;
@end

@implementation UAUserCreateResponse

- (instancetype)initWithStatus:(NSUInteger)status userData:(UAUserData *)userData {
    self = [super init];

    if (self) {
        self.status = status;
        self.userData = userData;
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
    return [NSString stringWithFormat:@"UAUserCreateResponse(status=%ld)", self.status];
}

@end

@interface UAUserAPIClient()
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@end

@implementation UAUserAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
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
    return [UAUserAPIClient clientWithConfig:config session:[[UARequestSession alloc] initWithConfig:config]];
}

- (UADisposable *)createUserWithChannelID:(NSString *)channelID
                        completionHandler:(void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))completionHandler {

    NSDictionary *requestBody =  @{
        @"ios_channels": @[channelID]
    };

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *createURLString = [NSString stringWithFormat:@"%@%@",
                                     self.config.deviceAPIURL,
                                     @"/api/user/"];

        builder.url = [NSURL URLWithString:createURLString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;

        [builder setValue:@"application/json" header:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];

        builder.body = [UAJSONUtils dataWithObject:requestBody
                                                       options:0
                                                         error:nil];
    }];

    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completionHandler(nil, error);
        } else if (response.statusCode == 201 || response.statusCode == 200) {
            UAUserData *userData = [UAUserAPIClient parseResponseData:data error:&error];
            completionHandler([[UAUserCreateResponse alloc] initWithStatus:response.statusCode userData:userData], error);
        } else {
            completionHandler([[UAUserCreateResponse alloc] initWithStatus:response.statusCode userData:nil], nil);
        }
    }];
}

- (UADisposable *)updateUserWithData:(UAUserData *)userData
                           channelID:(NSString *)channelID
                   completionHandler:(void (^)(UAHTTPResponse *response, NSError * _Nullable error))completionHandler {

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

        builder.url = [NSURL URLWithString:updateURLString];
        builder.method = @"POST";
        builder.username = userData.username;
        builder.password = userData.password;

        [builder setValue:@"application/json" header:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];

        builder.body = [UAJSONUtils dataWithObject:requestBody
                                                       options:0
                                                         error:nil];
    }];

    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}


+ (UAUserData *)parseResponseData:(NSData *)data error:(NSError **)error {
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSString *username = [jsonResponse objectForKey:@"user_id"];
    NSString *password = [jsonResponse objectForKey:@"password"];

    if (!username || !password) {
        NSString *msg = [NSString stringWithFormat:@"User API failed. Unable to parse response %@", jsonResponse];
        *error = [UAirshipErrors parseError:msg];
        return nil;
    }

    return [UAUserData dataWithUsername:username password:password];
}


@end
