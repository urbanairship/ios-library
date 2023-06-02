/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUAInAppMessageDefaultDisplayInterval 0

@class UADispatcher;

@interface UAInAppMessageDefaultDisplayCoordinator ()

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter;

@end
