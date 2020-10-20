/* Copyright Airship and Contributors */

#import "UAAPIClient.h"
#import "UARequestSession.h"
#import "UARuntimeConfig.h"
#import "UAirship.h"

NSUInteger const UAAPIClientStatusUnavailable = 0;
NSString * const UAAPIClientErrorDomain = @"com.urbanairship.api_client";

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

- (NSHTTPURLResponse *)castResponse:(NSURLResponse *)response error:(NSError **)error {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        return (NSHTTPURLResponse *)response;
    }

    if (!*error) {
        NSString *msg = [NSString stringWithFormat:@"Unable to cast to NSHTTPURLResponse: %@", response];
        
        *error = [NSError errorWithDomain:UAAPIClientErrorDomain
                                     code:UAAPIClientErrorInvalidURLResponse
                                 userInfo:@{NSLocalizedDescriptionKey:msg}];
    }

    return nil;
}

- (void)dealloc {
    [self.session cancelAllRequests];
}

@end
