/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UALegacyInAppMessage;
@class UAInAppMessageScheduleInfo;
@class UAInAppMessageScheduleInfoBuilder;
@class UAInAppMessageBuilder;

NS_ASSUME_NONNULL_BEGIN

/**
 * A delegate protocol for bridging legacy in-app messages with the v2 infrastructure.
 */
@protocol UALegacyInAppMessageFactoryDelegate <NSObject>

@required

/**
 * Converts a legacy in-app message model object into an in-app message schedule info.
 * Use this method to override the conversion process in its entirety.
 *
 * @param message The legacy in-app message model object.
 * @return An instance of UAInAppMessageScheduleInfo.
 */
- (UAInAppMessageScheduleInfo *)scheduleInfoForMessage:(UALegacyInAppMessage *)message;

@end

/**
 * A protocol for extending the default conversion between legacy in-app messages and v2 scheduled messages.
 */
@protocol UALegacyInAppMessageBuilderExtender <NSObject>

@optional

/**
 * Extends the in-app message schedule info builder converted from a legacy in-app message model object.
 * Use this method to make use of the default conversion with minor overrides as needed.
 *
 * @param builder The automatically converted in-app message schedule info builder.
 * @param message The legacy in-app message model object.
 */
- (void)extendScheduleInfoBuilder:(UAInAppMessageScheduleInfoBuilder *)builder message:(UALegacyInAppMessage *)message;

/**
 * Extends the in-app message builder converted from a legacy in-app message model object.
 * Use this method to make use of the automatic conversion process with minor overrides as needed.
 *
 * @param builder The automatically converted in-app message builder.
 * @param message The legacy in-app message model object.
 */
- (void)extendMessageBuilder:(UAInAppMessageBuilder *)builder message:(UALegacyInAppMessage *)message;

@end

/**
 * Manager class for in-app messaging.
 */
@interface UALegacyInAppMessaging : NSObject <UALegacyInAppMessageFactoryDelegate>

/**
 * Sets whether legacy messages will display immediately upon arrival, instead of waiting
 * until the following foreground. Defaults to `YES`.
 */
@property(nonatomic, assign) BOOL displayASAPEnabled;

/**
 * Optional factory delegate. Set this to provide a custom implementation of legacy in-app message support.
 */
@property(nonatomic, weak) id<UALegacyInAppMessageFactoryDelegate> factoryDelegate;

/*
 * Optional schedule builder extender. Set this to customize aspects of the conversion between legacy in-app message
 * model objects and builders for the new scheduled messages.
 */
@property(nonatomic, weak) id<UALegacyInAppMessageBuilderExtender> builderExtender;

@end

NS_ASSUME_NONNULL_END
