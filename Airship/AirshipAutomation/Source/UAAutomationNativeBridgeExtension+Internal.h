/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"

#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Automation native bridge extension.
 */
@interface UAAutomationNativeBridgeExtension : NSObject<UANativeBridgeExtensionDelegate>

/**
 * UAAutomationNativeBridgeExtension factory method.
 *
 * @param message The message.
 */
+ (instancetype)extensionWithMessage:(UAInAppMessage *)message;

@end

NS_ASSUME_NONNULL_END
