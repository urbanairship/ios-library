/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UADispatcher+Internal.h"

@interface UAInAppMessageDefaultDisplayCoordinator ()

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter;

@end
