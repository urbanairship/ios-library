/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAAppStateTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAUIKitStateTracker : NSObject <UAAppStateTracker>

+ (instancetype)trackerWithApplication:(UIApplication *)application
                    notificationCenter:(NSNotificationCenter *)notificationCenter;

@property(nonatomic, readonly) UAApplicationState state;

@end

NS_ASSUME_NONNULL_END
