
#import "UAPush+Test.h"
#import "JRSwizzle.h"

static id mockPush = nil;

@implementation UAPush (Test)

+ (id)mockShared {
    return mockPush;
}

+ (void)swizzleShared {
    [self jr_swizzleClassMethod:@selector(shared) withClassMethod:@selector(mockShared) error:nil];
}

+ (void)unswizzleShared {
    [self jr_swizzleClassMethod:@selector(mockShared) withClassMethod:@selector(shared) error:nil];
}

+ (void)configure:(id)instance {
    mockPush = instance;
    [self swizzleShared];
}

+ (void)reset {
    mockPush = nil;
    [self unswizzleShared];
}

@end