/* Copyright Airship and Contributors */

#import "UAInboxAPIClient+Internal.h"
#import "UAUser.h"

#import "UAAirshipMessageCenterCoreImport.h"

@interface UAInboxAPIClient()

@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAInboxAPIClient

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithConfig:config session:session];

    if (self) {
        self.user = user;
        self.dataStore = dataStore;
    }

    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInboxAPIClient alloc] initWithConfig:config session:session user:user dataStore:dataStore];
}

- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock {

    if (!self.enabled) {
        successBlock(UAAPIClientStatusUnavailable, nil);
        return;
    }

    [self.user getUserData:^(UAUserData *userData) {
        if (!userData) {
            UA_LWARN(@"User is not created, unable to retrieve message list.");
            successBlock(UAAPIClientStatusUnavailable, nil);
            return;
        }

        UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {

            NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                                   self.config.deviceAPIURL, @"/api/user/", userData.username,@"/messages/"];

            NSURL *requestUrl = [NSURL URLWithString: urlString];

            builder.URL = requestUrl;
            builder.method = @"GET";
            builder.username = userData.username;
            builder.password = userData.password;

            [builder setValue:[UAirship channel].identifier forHeader:kUAChannelIDHeader];

            NSString *lastModified = [self.dataStore stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];
            if (lastModified) {
                [builder setValue:lastModified forHeader:@"If-Modified-Since"];
            }

            UA_LTRACE(@"Request to retrieve message list: %@", urlString);
        }];

        [self performRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response) {
            return NO;
        } completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
            // 304, no changes
            if (response.statusCode == 304) {
                successBlock(response.statusCode, nil);
                return;
            }

            // Failure
            if (response.statusCode != 200) {
                [UAUtils logFailedRequest:request withMessage:@"Retrieve messages failed" withError:error withResponse:response];
                failureBlock();
                return;
            }

            // Missing response body
            if (!data) {
                UA_LTRACE(@"Retrieve messages list missing response body.");
                failureBlock();
                return;
            }

            // Success
            NSArray *messages = nil;
            NSDictionary *headers = response.allHeaderFields;
            NSString *lastModified = [headers objectForKey:@"Last-Modified"];

            // Parse the response
            NSError *parseError;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            messages = [jsonResponse objectForKey:@"messages"];

            if (!messages) {
                UA_LERR(@"Unable to parse inbox message body: %@ Error: %@", data, parseError);
                failureBlock();
                return;
            }

            UA_LTRACE(@"Retrieved message list with status: %ld jsonResponse: %@", (unsigned long)response.statusCode, jsonResponse);

            UA_LTRACE(@"Setting Last-Modified time to '%@' for user %@'s message list.", lastModified, userData.username);
            [self.dataStore setValue:lastModified
                              forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];

            successBlock(response.statusCode, messages);
        }];

    }];
}


- (void)performBatchDeleteForMessageReporting:(NSArray<NSDictionary *> *)messageReporting
                            onSuccess:(UAInboxClientSuccessBlock)successBlock
                            onFailure:(UAInboxClientFailureBlock)failureBlock {
    if (!self.enabled) {
        successBlock();
        return;
    }

    [self.user getUserData:^(UAUserData *userData) {
        if (!userData) {
            UA_LWARN(@"User is not created, unable to delete message reporting: %@", messageReporting);
            successBlock();
            return;
        }

        UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
            NSDictionary *data = @{@"messages" : messageReporting };

            NSData* body = [UAJSONSerialization dataWithJSONObject:data
                                                           options:0
                                                             error:nil];

            NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                                   self.config.deviceAPIURL,
                                   @"/api/user/",
                                   userData.username,
                                   @"/messages/delete/"];

            builder.URL = [NSURL URLWithString:urlString];
            builder.method = @"POST";
            builder.username = userData.username;
            builder.password = userData.password;
            builder.body = body;
            [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
            [builder setValue:@"application/json" forHeader:@"Content-Type"];
            [builder setValue:[UAirship channel].identifier forHeader:kUAChannelIDHeader ];

            UA_LTRACE(@"Request to perform batch delete: %@  body: %@", urlString, body);

        }];


        [self performRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response) {
            return NO;
        }
           completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

            // Failure
            if (response.statusCode != 200) {
                [UAUtils logFailedRequest:request withMessage:@"Batch delete failed" withError:error withResponse:response];

                failureBlock();

                return;
            }

            // Success
            successBlock();
        }];
    }];
}

- (void)performBatchMarkAsReadForMessageReporting:(NSArray<NSDictionary *> *)messageReporting
                                   onSuccess:(UAInboxClientSuccessBlock)successBlock
                                   onFailure:(UAInboxClientFailureBlock)failureBlock {

    if (!self.enabled) {
        successBlock();
        return;
    }

    [self.user getUserData:^(UAUserData *userData) {
        if (!userData) {
            UA_LWARN(@"User is not created, unable to mark messages as read: %@", messageReporting);
            successBlock();
            return;
        }

        UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
            NSDictionary *data = @{@"messages" : messageReporting };

            NSData* body = [UAJSONSerialization dataWithJSONObject:data
                                                           options:0
                                                             error:nil];

            NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                                   self.config.deviceAPIURL,
                                   @"/api/user/",
                                   userData.username,
                                   @"/messages/unread/"];

            builder.URL = [NSURL URLWithString:urlString];
            builder.method = @"POST";
            builder.username = userData.username;
            builder.password = userData.password;
            builder.body = body;
            [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
            [builder setValue:@"application/json" forHeader:@"Content-Type"];
            [builder setValue:[UAirship channel].identifier forHeader:kUAChannelIDHeader];

            UA_LTRACE(@"Request to perfom batch mark messages as read: %@ body: %@", urlString, body);
        }];

        [self performRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response) {
            return NO;
        } completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
            // Failure
            if (response.statusCode != 200) {
                [UAUtils logFailedRequest:request withMessage:@"Batch delete failed" withError:error withResponse:response];
                failureBlock();
                return;
            }

            // Success
            successBlock();
        }];
    }];
}

- (void)clearLastModifiedTime {
    [self.user getUserData:^(UAUserData *userData) {
        if (userData.username) {
            [self.dataStore removeObjectForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];
        }
    }];
}

@end
