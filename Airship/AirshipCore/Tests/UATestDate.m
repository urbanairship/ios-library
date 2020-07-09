/* Copyright Airship and Contributors */

#import "UATestDate.h"

@implementation UATestDate

- (instancetype)initWithTimeOffset:(NSTimeInterval)offset {
    if (self = [super init]) {
        self.timeOffset = offset;
    }

    return self;
}

- (instancetype)initWithAbsoluteTime:(NSDate *)date {
    if (self = [super init]) {
        self.absoluteTime = date;
    }

    return self;
}

- (instancetype)init {
    return [self initWithTimeOffset:0];
}

- (NSDate *)now {
    NSDate *date = self.absoluteTime ? : [NSDate date];
    return [date dateByAddingTimeInterval:self.timeOffset];
}

@end
