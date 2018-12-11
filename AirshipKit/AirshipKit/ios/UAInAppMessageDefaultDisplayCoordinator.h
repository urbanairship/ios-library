/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A default implementation of the UAInAppMessageDisplayCoordinator protocol. Use this class as a reference
 *  implementation, or subclass for custom implementations or coordination behavior overrides.
 */
@interface UAInAppMessageDefaultDisplayCoordinator : NSObject <UAInAppMessageDisplayCoordinator>

/**
 * The allowed time interval between message displays. Defaults to 30 seconds.
 */
@property (nonatomic, assign) NSTimeInterval displayInterval;

/**
 * UAInAppMessageDefaultDisplayCoordinator class factory method.
 */
+ (instancetype)coordinator;

@end

NS_ASSUME_NONNULL_END
