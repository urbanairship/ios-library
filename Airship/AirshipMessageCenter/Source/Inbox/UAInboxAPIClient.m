/* Copyright Airship and Contributors */

#import "UAInboxAPIClient+Internal.h"
#import "UAUser.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString * const UAInboxAPIClientErrorDomain = @"com.urbanairship.inbox_api_client";

@interface UAInboxAPIClient()

@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSMutableArray<UADisposable *> *disposables;

@end

@implementation UAInboxAPIClient

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
        self.user = user;
        self.dataStore = dataStore;
        self.disposables = [NSMutableArray array];
    }

    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInboxAPIClient alloc] initWithConfig:config session:session user:user dataStore:dataStore];
}

- (nullable NSArray *)retrieveMessageList:(NSError **)error {
    UAUserData *userData = [self.user getUserDataSync];

    if (!userData) {
        UA_LWARN(@"User is not created, unable to retrieve message list.");
        return nil;
    }

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {

        NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                               self.config.deviceAPIURL, @"/api/user/", userData.username,@"/messages/"];

        NSURL *requestUrl = [NSURL URLWithString: urlString];

        builder.url = requestUrl;
        builder.method = @"GET";
        builder.username = userData.username;
        builder.password = userData.password;

        [builder setValue:[UAirship channel].identifier header:kUAChannelIDHeader];

        NSString *lastModified = [self.dataStore stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];
        if (lastModified) {
            [builder setValue:lastModified header:@"If-Modified-Since"];
        }

        UA_LTRACE(@"Request to retrieve message list: %@", urlString);
    }];

    UASemaphore *semaphore = [[UASemaphore alloc] init];

    __block NSData *data;
    __block NSHTTPURLResponse *response;
    __block NSError *requestError;

    UADisposable *disposable = [self.session performHTTPRequest:request completionHandler:^(NSData * _data, NSHTTPURLResponse * _response, NSError * _error) {
        data = _data;
        response = _response;
        requestError = _error;
        [semaphore signal];
    }];

    @synchronized (self) {
        [self.disposables addObject:disposable];
    }

    [semaphore wait];

    @synchronized (self) {
        [self.disposables removeObject:disposable];
    }

    if (requestError) {
        *error = requestError;
        UA_LERR(@"Error retrieving message list: %@", requestError);
        return nil;
    }

    NSUInteger status = response.statusCode;

    // 304, no changes
    if (status == 304) {
        return nil;
    }

    // Failure
    if (status != 200) {
        NSString *msg = [NSString stringWithFormat:@"Inbox API client encountered an unsuccessful status"];
        *error = [NSError errorWithDomain:UAInboxAPIClientErrorDomain
                                     code:UAInboxAPIClientErrorUnsuccessfulStatus
                                 userInfo:@{NSLocalizedDescriptionKey : msg}];

        [UAUtils logFailedRequest:request withMessage:@"Retrieve messages failed" withError:*error withResponse:response];
        return nil;
    }

    // Missing response body
    if (!data) {
        NSString *msg = [NSString stringWithFormat:@"Inbox API client response is invalid"];
        *error = [NSError errorWithDomain:UAInboxAPIClientErrorDomain
                                     code:UAInboxAPIClientErrorInvalidResponse
                                 userInfo:@{NSLocalizedDescriptionKey : msg}];

        UA_LTRACE(@"Retrieve messages list missing response body.");
        return nil;
    }

    // Success
    NSArray *messages = nil;
    NSDictionary *headers = response.allHeaderFields;
    NSString *lastModified = [headers objectForKey:@"Last-Modified"];

    // Parse the response
    NSError *parseError;
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:error];
    messages = [jsonResponse objectForKey:@"messages"];

    if (!messages) {
        NSString *msg = [NSString stringWithFormat:@"Inbox API client response is invalid"];
        *error = [NSError errorWithDomain:UAInboxAPIClientErrorDomain
                                     code:UAInboxAPIClientErrorInvalidResponse
                                 userInfo:@{NSLocalizedDescriptionKey : msg}];

        UA_LERR(@"Unable to parse inbox message body: %@ Error: %@", data, parseError);
        return nil;
    }

    UA_LTRACE(@"Retrieved message list with status: %ld jsonResponse: %@", status, jsonResponse);

    UA_LTRACE(@"Setting Last-Modified time to '%@' for user %@'s message list.", lastModified, userData.username);
    [self.dataStore setValue:lastModified
                      forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];

    return messages;
}

- (BOOL)performBatchDeleteForMessageReporting:(NSArray<NSDictionary *> *)messageReporting {
    UAUserData *userData = [self.user getUserDataSync];
    if (!userData) {
        UA_LWARN(@"User is not created, unable to delete message reporting: %@", messageReporting);
        return YES;
    }

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSDictionary *body = @{@"messages" : messageReporting };

        NSData* bodyData = [UAJSONUtils dataWithObject:body
                                                           options:0
                                                             error:nil];

        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/",
                               userData.username,
                               @"/messages/delete/"];

        builder.url = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = userData.username;
        builder.password = userData.password;
        builder.body = bodyData;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];
        [builder setValue:@"application/json" header:@"Content-Type"];
        [builder setValue:[UAirship channel].identifier header:kUAChannelIDHeader ];

        UA_LTRACE(@"Request to perform batch delete: %@  body: %@", urlString, body);
    }];

    UASemaphore *semaphore = [[UASemaphore alloc] init];

    __block NSData *data;
    __block NSHTTPURLResponse *response;
    __block NSError *error;

    UADisposable *disposable = [self.session performHTTPRequest:request completionHandler:^(NSData * _data, NSHTTPURLResponse * _response, NSError * _error) {
        data = _data;
        response = _response;
        error = _error;
        [semaphore signal];
    }];

    @synchronized (self) {
        [self.disposables addObject:disposable];
    }

    [semaphore wait];

    @synchronized (self) {
        [self.disposables removeObject:disposable];
    }

    if (response.statusCode != 200) {
        [UAUtils logFailedRequest:request withMessage:@"Batch delete failed" withError:error withResponse:response];
        return NO;
    }

    return YES;
}

- (BOOL)performBatchMarkAsReadForMessageReporting:(NSArray<NSDictionary *> *)messageReporting {
    UAUserData *userData = [self.user getUserDataSync];
    if (!userData) {
        UA_LWARN(@"User is not created, unable to mark messages as read: %@", messageReporting);
        return YES;
    }

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSDictionary *body = @{@"messages" : messageReporting };

        NSData* bodyData = [UAJSONUtils dataWithObject:body
                                                           options:0
                                                             error:nil];

        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/",
                               userData.username,
                               @"/messages/unread/"];

        builder.url = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = userData.username;
        builder.password = userData.password;
        builder.body = bodyData;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];
        [builder setValue:@"application/json" header:@"Content-Type"];
        [builder setValue:[UAirship channel].identifier header:kUAChannelIDHeader];

        UA_LTRACE(@"Request to perfom batch mark messages as read: %@ body: %@", urlString, body);
    }];

    UASemaphore *semaphore = [[UASemaphore alloc] init];

    __block NSData *data;
    __block NSHTTPURLResponse *response;
    __block NSError *error;

    UADisposable *disposable = [self.session performHTTPRequest:request completionHandler:^(NSData * _data, NSHTTPURLResponse * _response, NSError * _error) {
        data = _data;
        response = _response;
        error = _error;
        [semaphore signal];
    }];

    @synchronized (self) {
        [self.disposables addObject:disposable];
    }

    [semaphore wait];

    @synchronized (self) {
        [self.disposables removeObject:disposable];
    }

    if (response.statusCode != 200) {
        [UAUtils logFailedRequest:request withMessage:@"Batch mark as read failed" withError:error withResponse:response];
        return NO;
    }

    return YES;
}

- (void)clearLastModifiedTime {
    [self.user getUserData:^(UAUserData *userData) {
        if (userData.username) {
            [self.dataStore removeObjectForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userData.username]];
        }
    }];
}

- (void)cancelAllRequests {
    @synchronized (self) {
        for (UADisposable *disposable in self.disposables) {
            [disposable dispose];
        }

        [self.disposables removeAllObjects];
    }
}

@end
