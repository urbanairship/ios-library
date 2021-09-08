/* Copyright Airship and Contributors */

#import "UAScheduleDeferredData.h"
#import "NSDictionary+UAAdditions+Internal.h"

NSString *const UAScheduleDeferredDataErrorDomain = @"com.urbanairship.deferred_schedule_data";
static NSString *const UAScheduleDeferredDataURLKey = @"url";
static NSString *const UAScheduleDeferredDataRetryOnTimeoutKey = @"retry_on_timeout";
static NSString *const UAScheduleDeferredDataTypeKey = @"type";
static NSString *const UAScheduleDeferredDataTypeInAppMessageValue = @"in_app_message";

@interface UAScheduleDeferredData()
@property(nonatomic, copy) NSURL *URL;
@property(nonatomic, assign) BOOL retriableOnTimeout;
@property(nonatomic, assign) UAScheduleDataDeferredType type;
@end

@implementation UAScheduleDeferredData

- (instancetype)initWithURL:(NSURL *)URL
         retriableOnTimeout:(BOOL)retriableOnTimeout
                       type:(UAScheduleDataDeferredType)type {

    self = [super init];
    if (self) {
        self.URL = URL;
        self.retriableOnTimeout = retriableOnTimeout;
        self.type = type;
    }
    return self;
}

+ (instancetype)deferredDataWithURL:(NSURL *)URL
                retriableOnTimeout:(BOOL)retriableOnTimeout {
    return [[self alloc] initWithURL:URL retriableOnTimeout:retriableOnTimeout type:UAScheduleDataDeferredTypeUnknown];
}


+ (instancetype)deferredDataWithURL:(NSURL *)URL
                 retriableOnTimeout:(BOOL)retriableOnTimeout
                               type:(UAScheduleDataDeferredType)type {
    return [[self alloc] initWithURL:URL retriableOnTimeout:retriableOnTimeout type:type];
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


    UAScheduleDataDeferredType type = UAScheduleDataDeferredTypeUnknown;
    if ([UAScheduleDeferredDataTypeInAppMessageValue isEqualToString:[JSON stringForKey:UAScheduleDeferredDataTypeKey defaultValue:nil]]) {
        type = UAScheduleDataDeferredTypeInAppMessage;
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
                                    retriableOnTimeout:retryOnTimeout
                                                  type:type];
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setValue:[self.URL absoluteString] forKey:UAScheduleDeferredDataURLKey];
    [json setValue:@(self.retriableOnTimeout) forKey:UAScheduleDeferredDataRetryOnTimeoutKey];

    if (self.type == UAScheduleDataDeferredTypeInAppMessage) {
        [json setValue:UAScheduleDeferredDataTypeInAppMessageValue forKey:UAScheduleDeferredDataTypeKey];
    }

    return [NSDictionary dictionaryWithDictionary:json];
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
    return [self.URL isEqual:other.URL] && self.retriableOnTimeout == other.retriableOnTimeout && self.type == other.type;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.URL hash];
    result = 31 * result + self.retriableOnTimeout;
    result = 31 * result + self.type;
    return result;
}

@end
