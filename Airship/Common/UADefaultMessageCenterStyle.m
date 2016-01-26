
#import "UADefaultMessageCenterStyle.h"

@implementation UADefaultMessageCenterStyle

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default to disabling icons
        self.iconsEnabled = NO;
    }

    return self;
}

+ (instancetype)style {
    return [[self alloc] init];
}

@end
