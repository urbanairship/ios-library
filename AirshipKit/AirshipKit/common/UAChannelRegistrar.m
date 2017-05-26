/* Copyright 2017 Urban Airship and Contributors */

#import "UAChannelRegistrar+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAConfig.h"

@implementation UAChannelRegistrar

-(id)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.channelAPIClient = [UAChannelAPIClient clientWithConfig:config];
        self.isRegistrationInProgress = NO;
    }
    return self;
}

+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config {
    return [[UAChannelRegistrar alloc] initWithConfig:config];
}

- (void)registerWithChannelID:(NSString *)channelID
              channelLocation:(NSString *)channelLocation
                  withPayload:(UAChannelRegistrationPayload *)payload
                   forcefully:(BOOL)forcefully {

    UAChannelRegistrationPayload *payloadCopy = [payload copy];

    @synchronized(self) {
        if (self.isRegistrationInProgress) {
            UA_LDEBUG(@"Ignoring registration request, one already in progress.");
            return;
        }

        self.isRegistrationInProgress = YES;

        if (forcefully || ![payload isEqualToPayload:self.lastSuccessPayload]) {

            if (!channelID || !channelLocation) {
                [self createChannelWithPayload:payloadCopy];
            } else {
                [self updateChannel:channelID channelLocation:channelLocation withPayload:payloadCopy];
            }

        } else {
            UA_LDEBUG(@"Ignoring registration request, registration is up to date.");
            [self succeededWithPayload:payload];
        }
    }
}



- (void)cancelAllRequests {
    @synchronized(self) {
        [self.channelAPIClient cancelAllRequests];

        // If a registration was in progress, its undeterministic if it succeeded
        // or not, so just clear the last success payload.
        if (self.isRegistrationInProgress) {
            self.lastSuccessPayload = nil;
        }

        self.isRegistrationInProgress = NO;
    }
}

- (void)updateChannel:(NSString *)channelID
      channelLocation:(NSString *)location
          withPayload:(UAChannelRegistrationPayload *)payload {

    UA_LDEBUG(@"Updating channel %@", channelID);

    UAChannelAPIClientUpdateSuccessBlock successBlock = ^{
        [self succeededWithPayload:payload];
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {
        if (statusCode != 409) {
            UA_LDEBUG(@"Channel failed to update with JSON payload %@", [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);
            [self failedWithPayload:payload];
            return;
        }

        // Conflict with channel ID, create a new one
        UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *newChannelID, NSString *channelLocation, BOOL existing) {
            UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", newChannelID, channelLocation);
            [self channelCreated:newChannelID channelLocation:channelLocation existing:existing];
            [self succeededWithPayload:payload];
        };

        UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {
            UA_LDEBUG(@"Channel failed to create with JSON payload %@", [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);
            [self failedWithPayload:payload];
        };

        UA_LDEBUG(@"Channel conflict, recreating.");
        [self.channelAPIClient createChannelWithPayload:payload
                                              onSuccess:successBlock
                                              onFailure:failureBlock];
    };

    [self.channelAPIClient updateChannelWithLocation:location
                                         withPayload:payload
                                           onSuccess:successBlock
                                           onFailure:failureBlock];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload {

    UA_LDEBUG(@"Creating channel.");

    UAChannelAPIClientCreateSuccessBlock successBlock = ^(NSString *channelID, NSString *channelLocation, BOOL existing) {
        if (!channelID || !channelLocation) {
            UA_LDEBUG(@"Channel ID: %@ or channel location: %@ is missing. Channel creation failed",
                      channelID, channelLocation);
            [self failedWithPayload:payload];
        } else {
            UA_LDEBUG(@"Channel %@ created successfully. Channel location: %@.", channelID, channelLocation);
            [self channelCreated:channelID channelLocation:channelLocation existing:existing];
            [self succeededWithPayload:payload];
        }
    };

    UAChannelAPIClientFailureBlock failureBlock = ^(NSUInteger statusCode) {
        UA_LDEBUG(@"Channel creation failed.");
        [self failedWithPayload:payload];
    };

    [self.channelAPIClient createChannelWithPayload:payload
                                          onSuccess:successBlock
                                          onFailure:failureBlock];
}

- (void)failedWithPayload:(UAChannelRegistrationPayload *)payload {
    @synchronized(self) {
        if (!self.isRegistrationInProgress) {
            return;
        }

        self.isRegistrationInProgress = NO;

        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationFailedWithPayload:)]) {
            [strongDelegate registrationFailedWithPayload:payload];
        }
    }
}

- (void)succeededWithPayload:(UAChannelRegistrationPayload *)payload {
    @synchronized(self) {
        if (!self.isRegistrationInProgress) {
            return;
        }

        self.lastSuccessPayload = payload;
        self.isRegistrationInProgress = NO;

        id strongDelegate = self.delegate;
        if ([strongDelegate respondsToSelector:@selector(registrationSucceededWithPayload:)]) {
            [strongDelegate registrationSucceededWithPayload:payload];
        }
    }
}

- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing {

    id strongDelegate = self.delegate;

    if ([strongDelegate respondsToSelector:@selector(channelCreated:channelLocation:existing:)]) {
        [strongDelegate channelCreated:channelID channelLocation:channelLocation existing:existing];
    }
}

@end
