/* Copyright Airship and Contributors */

#import "UAAuthTokenManager+Internal.h"

@interface UAAuthTokenManager ()
@property(nonatomic, strong) UAAuthTokenAPIClient *client;
@property(nonatomic, strong) UAChannel *channel;
@property(nonatomic, strong) UAAuthToken *cachedToken;
@property(nonatomic, strong) UADate *date;
@property(nonatomic, strong) dispatch_queue_t requestQueue;
@end

@implementation UAAuthTokenManager

- (instancetype)initWithAPIClient:(UAAuthTokenAPIClient *)client channel:(UAChannel *)channel date:(UADate *)date {
    self = [super init];

    if (self) {
        self.client = client;
        self.channel = channel;
        self.date = date;

        self.requestQueue = dispatch_queue_create("com.urbanairship.auth_token_manager.request_queue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

+ (instancetype)authTokenManagerWithAPIClient:(UAAuthTokenAPIClient *)client channel:(UAChannel *)channel date:(UADate *)date {
    return [[self alloc] initWithAPIClient:client channel:channel date:date];
}

+ (instancetype)authTokenManagerWithRuntimeConfig:(UARuntimeConfig *)config channel:(UAChannel *)channel {
    UAAuthTokenAPIClient *client = [UAAuthTokenAPIClient clientWithConfig:config];
    return [[self alloc] initWithAPIClient:client channel:channel date:[[UADate alloc] init]];
}

- (void)tokenWithCompletionHandler:(void (^)(NSString *))completionHandler {
    dispatch_async(self.requestQueue, ^{
        if (!self.channel.identifier) {
            return completionHandler(nil);
        }

        UAAuthToken *cachedToken = self.cachedToken;

        if (cachedToken) {
            return completionHandler(cachedToken.token);
        }

        __block UAAuthToken *responseToken;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [self.client tokenWithChannelID:self.channel.identifier completionHandler:^(UAAuthToken * _Nullable token, NSError * _Nullable error) {
            if (!token || error) {
                UA_LDEBUG(@"Unable to retrieve auth token: %@", error);
            }

            responseToken = token;

            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        if (!responseToken) {
            return completionHandler(nil);
        }

        self.cachedToken = responseToken;
        completionHandler(responseToken.token);
    });
}

- (void)expireToken:(NSString *)token {
    UA_WEAKIFY(self)
    dispatch_async(self.requestQueue, ^{
        UA_STRONGIFY(self)
        if ([token isEqualToString:self->_cachedToken.token]) {
            self->_cachedToken = nil;
        }
    });
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
