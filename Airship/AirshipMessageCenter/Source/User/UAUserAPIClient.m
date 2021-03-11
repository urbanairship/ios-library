/* Copyright Airship and Contributors */

#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "NSError+UAAdditions.h"

@interface UAUserCreateResponse()
@property(nonatomic, strong) UAUserData *userData;
@end

@implementation UAUserCreateResponse

- (instancetype)initWithStatus:(NSUInteger)status userData:(UAUserData *)userData {
    self = [super initWithStatus:status];

    if (self) {
        self.userData = userData;
    }

    return self;
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
    return [UAUserAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
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
        *error = [NSError airshipParseErrorWithMessage:msg];
        return nil;
    }

    return [UAUserData dataWithUsername:username password:password];
}


@end
