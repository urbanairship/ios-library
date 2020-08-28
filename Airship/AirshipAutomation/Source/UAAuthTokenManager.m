/* Copyright Airship and Contributors */

#import "UAAuthTokenManager+Internal.h"

@interface UAAuthTokenManager ()
@property(nonatomic, strong) UAAuthTokenAPIClient *client;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAAuthToken *cachedToken;
@property(nonatomic, strong) UADate *date;
@property(nonatomic, strong) UADispatcher *requestDispatcher;
@end

@implementation UAAuthTokenManager

- (instancetype)initWithAPIClient:(UAAuthTokenAPIClient *)client
                          channel:(UAChannel *)channel
                             date:(UADate *)date
                       dispatcher:(UADispatcher *)dispatcher {

    self = [super init];

    if (self) {
        self.client = client;
        self.channel = channel;
        self.date = date;
        self.requestDispatcher = dispatcher;
    }

    return self;
}

+ (instancetype)authTokenManagerWithAPIClient:(UAAuthTokenAPIClient *)client
                                      channel:(UAChannel *)channel
                                         date:(UADate *)date
                                   dispatcher:(UADispatcher *)dispatcher {

    return [[self alloc] initWithAPIClient:client
                                   channel:channel
                                      date:date
                                dispatcher:dispatcher];
}

+ (instancetype)authTokenManagerWithRuntimeConfig:(UARuntimeConfig *)config channel:(UAChannel *)channel {
    UAAuthTokenAPIClient *client = [UAAuthTokenAPIClient clientWithConfig:config];

    return [[self alloc] initWithAPIClient:client
                                   channel:channel
                                      date:[[UADate alloc] init]
                                dispatcher:[UADispatcher serialDispatcher]];
}

- (void)tokenWithCompletionHandler:(void (^)(NSString *))completionHandler {
    [self.requestDispatcher dispatchAsync:^{
        if (!self.channel.identifier) {
            return completionHandler(nil);
        }

        UAAuthToken *cachedToken = self.cachedToken;

        if (cachedToken) {
            return completionHandler(cachedToken.token);
        }

        __block UAAuthToken *responseToken;
        __block UASemaphore *semaphore = [UASemaphore semaphore];

        [self.client tokenWithChannelID:self.channel.identifier completionHandler:^(UAAuthToken * _Nullable token, NSError * _Nullable error) {
            if (!token || error) {
                UA_LDEBUG(@"Unable to retrieve auth token: %@", error);
            }

            responseToken = token;

            [semaphore signal];
        }];

        [semaphore wait];

        if (!responseToken) {
            return completionHandler(nil);
        }

        self.cachedToken = responseToken;
        completionHandler(responseToken.token);
    }];
}

- (void)expireToken:(NSString *)token {
    UA_WEAKIFY(self)
    [self.requestDispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        if ([token isEqualToString:self->_cachedToken.token]) {
            self->_cachedToken = nil;
        }
    }];
}

- (UAAuthToken *)cachedToken {
    if (!_cachedToken) {
        return nil;
    }

    if ([[self.date now] compare:_cachedToken.expiration] == NSOrderedDescending) {
        _cachedToken = nil;
        return nil;
    }

    if (![self.channel.identifier isEqualToString:_cachedToken.channelID]) {
        _cachedToken = nil;
        return nil;
    }

    return _cachedToken;
}

@end
