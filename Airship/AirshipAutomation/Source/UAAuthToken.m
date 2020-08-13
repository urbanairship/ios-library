/* Copyright Airship and Contributors */

#import "UAAuthToken+Internal.h"

@interface UAAuthToken ()
@property(nonatomic, copy) NSString *channelID;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, strong) NSDate *expiration;
@end

@implementation UAAuthToken

- (instancetype)initWithChannelID:(NSString *)channelID token:(NSString *)token expiration:(NSDate *)expiration {
    self = [super init];

    if (self) {
        self.channelID = channelID;
        self.token = token;
        self.expiration = expiration;
    }

    return self;
}


+ (instancetype)authTokenWithChannelID:(NSString *)channelID token:(NSString *)token expiration:(NSDate *)expiration {
    return [[self alloc] initWithChannelID:channelID token:token expiration:expiration];
}

@end
