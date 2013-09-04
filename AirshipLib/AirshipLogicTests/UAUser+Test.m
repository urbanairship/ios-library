
#import "UAUser+Test.h"
#import "JRSwizzle.h"

@implementation UAUser(Test)

+ (void)swizzleDefaultUserCreated {
    [self jr_swizzleMethod:@selector(defaultUserCreated) withMethod:@selector(defaultUserCreatedAlways) error:nil];
}

+ (void)unswizzleDefaultUserCreated {
    [self jr_swizzleMethod:@selector(defaultUserCreatedAlways) withMethod:@selector(defaultUserCreated) error:nil];
}

- (BOOL)defaultUserCreatedAlways {
    return YES;
}

@end
