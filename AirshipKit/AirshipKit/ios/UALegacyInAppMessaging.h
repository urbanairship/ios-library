/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UALegacyInAppMessage;
@class UAInAppMessageScheduleInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * A delegate protocol for bridging legacy in-app messages with the v2 infrastructure.
 */
@protocol UALegacyInAppMessageFactoryDelegate <NSObject>

@required

/**
 * Converts a legacy in-app message model object into an in-app message schedule info.
 */
- (UAInAppMessageScheduleInfo *)scheduleInfoForMessage:(UALegacyInAppMessage *)message;

@end

/**
 * Manager class for in-app messaging.
 */
@interface UALegacyInAppMessaging : NSObject <UALegacyInAppMessageFactoryDelegate>

/**
 * Optional factory delegate. Set this to provide a custom implementation of legacy in-app message support.
 */
@property(nonatomic, weak) id<UALegacyInAppMessageFactoryDelegate> factoryDelegate;

/**
 * Sets whether legacy messages will display immediately upon arrival, instead of waiting
 * until the following foreground. Defaults to `YES`.
 */
@property(nonatomic, assign) BOOL displayASAPEnabled;

@end

NS_ASSUME_NONNULL_END
