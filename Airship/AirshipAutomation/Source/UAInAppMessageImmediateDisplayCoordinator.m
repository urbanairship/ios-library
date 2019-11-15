/* Copyright Airship and Contributors */

#import "UAInAppMessageImmediateDisplayCoordinator.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UAInAppMessageImmediateDisplayCoordinator

+ (instancetype)coordinator {
    return [[self alloc] init];
}

- (BOOL)isReady {
    return YES;
}

@end
