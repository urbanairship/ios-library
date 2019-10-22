/* Copyright Airship and Contributors */

#import "UADisposable+Internal.h"
#import "UAAutoDisposable.h"

@implementation UAAutoDisposable

- (instancetype)initWithDisposalBlock:(UADisposalBlock)block {
    self = [super initWithDisposalBlock:block];
    if (self) {
        [self dispose];
    }

    return self;
}

@end
