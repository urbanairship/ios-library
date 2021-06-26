/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUAInAppMessageDefaultDisplayInterval 30

@class UADispatcher;

@interface UAInAppMessageDefaultDisplayCoordinator ()

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter;

@end
