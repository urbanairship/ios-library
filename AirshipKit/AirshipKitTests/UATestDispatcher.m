/* Copyright 2018 Urban Airship and Contributors */

#import "UATestDispatcher.h"
#import "UAGlobal.h"

@interface UAScheduledBlockEntry : NSObject
@property (nonatomic, strong) void (^block)(void);
@property (nonatomic, assign) NSTimeInterval time;

+ (instancetype)entryWithBlock:(void (^)(void))block time:(NSTimeInterval)time;
@end

@implementation UAScheduledBlockEntry
- (instancetype)initWithBlock:(void (^)(void))block time:(NSTimeInterval)time {
    self = [super init];
    if (self) {
        self.block = block;
        self.time = time;
    }
    return self;
}

+ (instancetype)entryWithBlock:(void (^)(void))block time:(NSTimeInterval)time {
    return [[self alloc] initWithBlock:block time:time];
}
@end


@interface UATestDispatcher()
@property NSTimeInterval currentTime;
@property NSMutableArray *scheduledBlocks;
@end

@implementation UATestDispatcher

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentTime = 0;
        self.scheduledBlocks = [NSMutableArray array];
    }

    return self;
}

+ (instancetype)testDispatcher {
    return [[self alloc] init];
}

- (void)advanceTime:(NSTimeInterval)time {
    if (time < 0) {
        NSException *exception = [NSException
                                    exceptionWithName:@"UATestDispatcher"
                                    reason:@"Time traveling into the past is prohibited."
                                    userInfo:nil];
        @throw exception;
    }

    self.currentTime += time;

    NSMutableArray *handled = [NSMutableArray array];
    for (UAScheduledBlockEntry *entry in self.scheduledBlocks) {
        if (self.currentTime >= entry.time) {
            entry.block();
            [handled addObject:entry];
        }
    }

    [self.scheduledBlocks removeObjectsInArray:handled];
}

- (UADisposable *)dispatchAfter:(NSTimeInterval)delay block:(void (^)(void))block {
    if (delay < 0) {
        delay = 0;
    }

    id entry = [UAScheduledBlockEntry entryWithBlock:block time:self.currentTime + delay];
    [self.scheduledBlocks addObject:entry];

    UA_WEAKIFY(self)
    return [UADisposable disposableWithBlock:^{
        UA_STRONGIFY(self)
        [self.scheduledBlocks removeObject:entry];
    }];
}

- (void)dispatchAsync:(void (^)(void))block {
    block();
}

- (void)dispatchSync:(void (^)(void))block {
    block();
}

@end
