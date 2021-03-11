/* Copyright Airship and Contributors */

#import "UAHTTPResponse.h"

@interface UAHTTPResponse()
@property(nonatomic, assign) NSUInteger status;
@end

@implementation UAHTTPResponse

- (instancetype)initWithStatus:(NSUInteger)status {
    self = [super init];
    if (self) {
        self.status = status;
    }
    return self;
}

- (bool)isSuccess {
    return self.status >= 200 && self.status <= 299;
}

- (bool)isClientError  {
    return self.status >= 400 && self.status <= 499;
}

- (bool)isServerError  {
    return self.status >= 500 && self.status <= 599;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAHTTPResponse(status=%ld)", self.status];
}

@end
