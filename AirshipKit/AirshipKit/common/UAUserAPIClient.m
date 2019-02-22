/* Copyright Urban Airship and Contributors */

#import "UAUserAPIClient+Internal.h"
#import "UAConfig.h"
#import "UAUtils+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUser.h"
#import "UAUserData.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization+Internal.h"

@implementation UAUserAPIClient

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [UAUserAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

- (void)createUserWithChannelID:(NSString *)channelID
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    UA_WEAKIFY(self)
    [UAUtils getDeviceID:^(NSString *deviceID) {
        UA_STRONGIFY(self)

        NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":deviceID}];

        if (channelID.length) {
            [payload setObject:@[channelID] forKey:@"ios_channels"];
        }

        UARequest *request = [self requestToCreateUserWithPayload:payload];

        [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
            return [response hasRetriableStatus];
        } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = nil;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                httpResponse = (NSHTTPURLResponse *) response;
            }

            NSUInteger status = httpResponse.statusCode;

            // Failure
            if (status != 201) {
                UA_LTRACE(@"User creation failed with status: %ld error: %@", (unsigned long)status, error);
                failureBlock(status);
                return;
            }

            // Success
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

            NSString *username = [jsonResponse objectForKey:@"user_id"];
            NSString *password = [jsonResponse objectForKey:@"password"];
            NSString *url = [jsonResponse objectForKey:@"user_url"];

            UAUserData *userData = [UAUserData dataWithUsername:username password:password url:url];

            UA_LTRACE(@"Created user: %@", username);
            successBlock(userData, payload);
        }];
    } dispatcher:[UADispatcher mainDispatcher]];
}

- (void)updateUser:(UAUser *)user
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [payload setValue:@{@"add": @[channelID]} forKey:@"ios_channels"];
    }

    UA_WEAKIFY(self)
    [user getUserData:^(UAUserData *userData) {
        UA_STRONGIFY(self)
        UARequest *request = [self requestToUpdateUser:userData payload:payload];

        [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
            return [response hasRetriableStatus];
        } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = nil;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                httpResponse = (NSHTTPURLResponse *) response;
            }

            NSUInteger status = httpResponse.statusCode;

            // Failure
            if (status != 200 && status != 201) {
                UA_LTRACE(@"User update failed with status: %ld error: %@", (unsigned long)status, error);
                failureBlock(status);

                return;
            }

            // Success
            UA_LTRACE(@"Successfully updated user: %@", user);
            successBlock();
        }];
    }];
}

- (UARequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
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

        builder.body = [UAJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LTRACE(@"Request to create user with body: %@", builder.body);
    }];

    return request;
}

- (UARequest *)requestToUpdateUser:(UAUserData *)userData payload:(NSDictionary *)payload {
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

        builder.body = [UAJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LTRACE(@"Request to update user with body: %@", builder.body);
    }];

    return request;
}

@end
