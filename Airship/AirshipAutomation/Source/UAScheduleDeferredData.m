/* Copyright Airship and Contributors */

#import "UAScheduleDeferredData+Internal.h"
#import "NSDictionary+UAAdditions.h"

NSString *const UAScheduleDeferredDataErrorDomain = @"com.urbanairship.deferred_schedule_data";

NSString *const UAScheduleDeferredDataURLKey = @"url";
NSString *const UAScheduleDeferredDataRetryOnTimeoutKey = @"retry_on_timeout";

@interface UAScheduleDeferredData()
@property(nonatomic, copy) NSURL *URL;
@property(nonatomic, assign) BOOL retriableOnTimeout;
@end

@implementation UAScheduleDeferredData
- (instancetype)initWithURL:(NSURL *)URL
         retriableOnTimeout:(BOOL)retriableOnTimeout {
    self = [super init];
    if (self) {
        self.URL = URL;
        self.retriableOnTimeout = retriableOnTimeout;
    }
    return self;
}

+ (instancetype)deferredDataWithURL:(NSURL *)URL
                retriableOnTimeout:(BOOL)retriableOnTimeout {
    return [[self alloc] initWithURL:URL retriableOnTimeout:retriableOnTimeout];
}

+ (nullable instancetype)deferredDataWithJSON:(id)JSON
                                        error:(NSError * _Nullable *)error {
    if (![JSON isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", JSON];
            *error =  [NSError errorWithDomain:UAScheduleDeferredDataErrorDomain
                                          code:UAScheduleDeferredDataErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    NSString *URLString = [JSON stringForKey:UAScheduleDeferredDataURLKey defaultValue:nil];
    if (!URLString) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Missing URL: %@", JSON];
            *error =  [NSError errorWithDomain:UAScheduleDeferredDataErrorDomain
                                          code:UAScheduleDeferredDataErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    BOOL retryOnTimeout = [[JSON numberForKey:UAScheduleDeferredDataRetryOnTimeoutKey defaultValue:@(YES)] boolValue];
    return [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:URLString]
                                    retriableOnTimeout:retryOnTimeout];
}

- (NSDictionary *)toJSON {
    return @{
        UAScheduleDeferredDataURLKey: [self.URL absoluteString],
        UAScheduleDeferredDataRetryOnTimeoutKey: @(self.retriableOnTimeout)
    };
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (![other isKindOfClass:[self class]]) {
        return NO;
    }

    return [self isEqualToDeferredData:(UAScheduleDeferredData *)other];
}

- (BOOL)isEqualToDeferredData:(nullable UAScheduleDeferredData *)other {
    return [self.URL isEqual:other.URL] && self.retriableOnTimeout == other.retriableOnTimeout;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.URL hash];
    result = 31 * result + self.retriableOnTimeout;
    return result;
}

@end
