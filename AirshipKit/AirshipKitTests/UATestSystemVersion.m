/* Copyright Urban Airship and Contributors */

#import "UATestSystemVersion.h"

@implementation UATestSystemVersion

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentSystemVersion = @"999.999.999";
    }
    return self;
}

@end
