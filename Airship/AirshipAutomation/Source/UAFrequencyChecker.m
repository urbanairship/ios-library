/* Copyright Airship and Contributors */

#import "UAFrequencyChecker+Internal.h"

@interface UAFrequencyChecker ()
@property (nonatomic, copy) BOOL (^overLimitBlock)(void);
@property (nonatomic, copy) BOOL (^checkAndIncrementBlock)(void);
@end

@implementation UAFrequencyChecker

- (instancetype)initWithIsOverLimit:(BOOL (^)(void))overLimitBlock
                  checkAndIncrement:(BOOL (^)(void))checkAndIncrementBlock {
    if (self = [super init]) {
        self.overLimitBlock = overLimitBlock;
        self.checkAndIncrementBlock = checkAndIncrementBlock;
    }

    return self;
}

+ (instancetype)frequencyCheckerWithIsOverLimit:(BOOL (^)(void))overLimitBlock
                              checkAndIncrement:(BOOL (^)(void))checkAndIncrementBlock {
    return [[self alloc] initWithIsOverLimit:overLimitBlock
                         checkAndIncrement:checkAndIncrementBlock];
}

- (BOOL)isOverLimit {
    return self.overLimitBlock();
}

- (BOOL)checkAndIncrement {
    return self.checkAndIncrementBlock();
}

@end
