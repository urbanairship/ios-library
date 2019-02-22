/* Copyright Urban Airship and Contributors */

#import "UARetriable+Internal.h"

#define kUARetriableDefaultMinBackoffInterval 30 // 30 seconds
#define kUARetriableDefaultMaxBackoffInterval 60 * 5 // 5 minutes

@interface UARetriable ()
@property (nonatomic, copy) UARetriableRunBlock runBlock;
@property (nonatomic, copy) UARetriableCompletionHandler resultHandler;
@property (nonatomic, assign) NSTimeInterval minBackoffInterval;
@property (nonatomic, assign) NSTimeInterval maxBackoffInterval;
@end

@implementation UARetriable

- (instancetype)initWithRunBlock:(UARetriableRunBlock)runBlock
                   resultHandler:(nullable UARetriableCompletionHandler)resultHandler
              minBackoffInterval:(NSTimeInterval)minBackoffInterval
              maxBackoffInterval:(NSTimeInterval)maxBackoffInterval {

    self = [super init];

    if (self) {
        self.runBlock = runBlock;
        self.resultHandler = resultHandler;
        self.minBackoffInterval = minBackoffInterval;
        self.maxBackoffInterval = maxBackoffInterval;
    }

    return self;
}

+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock {
    return [[self alloc] initWithRunBlock:runBlock
                            resultHandler:nil
                       minBackoffInterval:kUARetriableDefaultMinBackoffInterval
                       maxBackoffInterval:kUARetriableDefaultMaxBackoffInterval];
}

+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock resultHandler:(UARetriableCompletionHandler)resultHandler {
    return [[self alloc] initWithRunBlock:runBlock
                            resultHandler:resultHandler
                       minBackoffInterval:kUARetriableDefaultMinBackoffInterval
                       maxBackoffInterval:kUARetriableDefaultMaxBackoffInterval];
}

+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock
                   minBackoffInterval:(NSTimeInterval)minBackoffInterval
                   maxBackoffInterval:(NSTimeInterval)maxBackoffInterval {

    return [[self alloc] initWithRunBlock:runBlock
                            resultHandler:nil
                       minBackoffInterval:minBackoffInterval
                       maxBackoffInterval:maxBackoffInterval];
}

+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock
                        resultHandler:(UARetriableCompletionHandler)resultHandler
                   minBackoffInterval:(NSTimeInterval)minBackoffInterval
                   maxBackoffInterval:(NSTimeInterval)maxBackoffInterval {

    return [[self alloc] initWithRunBlock:runBlock
                            resultHandler:resultHandler
                       minBackoffInterval:minBackoffInterval
                       maxBackoffInterval:maxBackoffInterval];
}

@end
