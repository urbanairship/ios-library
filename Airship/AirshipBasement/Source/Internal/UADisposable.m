/* Copyright Airship and Contributors */

#import "UADisposable.h"

@interface UADisposable ()
@property (nonatomic, copy)void (^disposalBlock)(void);
@end

@implementation UADisposable

- (instancetype)init:(void (^)(void))disposalBlock {
    self = [super init];

    if (self) {
        self.disposalBlock = disposalBlock;
    }

    return self;
}

- (void)dispose {
    @synchronized(self) {
        if (self.disposalBlock) {
            self.disposalBlock();
            self.disposalBlock = nil;
        }
    }
}


@end
