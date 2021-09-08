/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  An implementation of the UAInAppMessageDisplayCoordinator protocol that allows immediate display.
 */
NS_SWIFT_NAME(InAppMessageImmediateDisplayCoordinator)
@interface UAInAppMessageImmediateDisplayCoordinator : NSObject <UAInAppMessageDisplayCoordinator>

/**
 * Indicates whether message display is ready.
 */
@property (nonatomic, readonly) BOOL isReady;

/**
 * UAInAppMessageImmediateDisplayCoordinator class factory method.
 */
+ (instancetype)coordinator;

@end

NS_ASSUME_NONNULL_END
