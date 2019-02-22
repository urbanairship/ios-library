/* Copyright Urban Airship and Contributors */

#import "UATestDispatcher.h"
#import "UAGlobal.h"


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

- (NSString *)description {
    return [NSString stringWithFormat:@"UAScheduledBlockEntry { time = %g }", self.time];
}
@end


@interface UATestDispatcher()
@property NSTimeInterval currentTime;
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
        NSDate *currentDate = [NSDate dateWithTimeIntervalSince1970:self.currentTime];
        NSDate *entryDate = [NSDate dateWithTimeIntervalSince1970:entry.time];
        if ([currentDate compare:entryDate] != NSOrderedAscending) {
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

- (void)doSync:(void (^)(void))block {
    block();
}

@end
