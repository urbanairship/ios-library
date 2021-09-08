/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAAirshipAutomationCoreImport.h"

@class UALegacyInAppMessage;
@class UASchedule;
@class UAScheduleBuilder;
@class UAInAppMessageBuilder;

NS_ASSUME_NONNULL_BEGIN

/**
 * A delegate protocol for bridging legacy in-app messages with the v2 infrastructure.
 */
NS_SWIFT_NAME(LegacyInAppMessageFactoryDelegate)
@protocol UALegacyInAppMessageFactoryDelegate <NSObject>

@required

/**
 * Converts a legacy in-app message model object into an in-app automation.
 * Use this method to override the conversion process in its entirety.
 *
 * @param message The legacy in-app message model object.
 * @return An instance of UASchedule..
 */
- (UASchedule *)scheduleForMessage:(UALegacyInAppMessage *)message;

@end

/**
 * A protocol for extending the default conversion between legacy in-app messages and v2 scheduled messages.
 */
NS_SWIFT_NAME(LegacyInAppMessageBuilderExtender)
@protocol UALegacyInAppMessageBuilderExtender <NSObject>

@optional

/**
 * Extends the in-app automation schedule builder converted from a legacy in-app message model object.
 * Use this method to make use of the default conversion with minor overrides as needed.
 *
 * @param builder The automatically converted in-app schedule builder.
 * @param message The legacy in-app message model object.
 */
- (void)extendScheduleBuilder:(UAScheduleBuilder *)builder message:(UALegacyInAppMessage *)message;

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
NS_SWIFT_NAME(LegacyInAppMessaging)
@interface UALegacyInAppMessaging : NSObject<UAComponent, UALegacyInAppMessageFactoryDelegate>

/**
 * The shared InAppAutomation instance.
 */
@property (class, nonatomic, readonly, null_unspecified) UALegacyInAppMessaging *shared;

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
