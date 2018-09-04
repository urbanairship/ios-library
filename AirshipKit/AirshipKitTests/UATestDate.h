
#import "UADate+Internal.h"

@interface UATestDate : UADate

- (instancetype)initWithTimeOffset:(NSTimeInterval)offset;

@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, strong) NSDate *absoluteTime;

@end

