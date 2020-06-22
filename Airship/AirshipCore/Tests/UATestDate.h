/* Copyright Airship and Contributors */

#import "UADate.h"

@interface UATestDate : UADate

- (instancetype)initWithTimeOffset:(NSTimeInterval)offset;
- (instancetype)initWithAbsoluteTime:(NSDate *)date;

@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, strong) NSDate *absoluteTime;

@end

