/* Copyright Airship and Contributors */

#import "UAAPIClient+Internal.h"
#import "UARequestSession+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship.h"

NSUInteger const UAAPIClientStatusUnavailable = 0;

@interface UAAPIClient()
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;
@end

@implementation UAAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
        self.enabled = YES;
    }

    return self;
}

- (void)cancelAllRequests {
    [self.session cancelAllRequests];
}

- (void)dealloc {
    [self.session cancelAllRequests];
}

@end
