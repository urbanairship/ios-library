/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageImmediateDisplayCoordinator.h"
#import "UAGlobal.h"

@implementation UAInAppMessageImmediateDisplayCoordinator

+ (instancetype)coordinator {
    return [[self alloc] init];
}

- (BOOL)isReady {
    return YES;
}

@end
