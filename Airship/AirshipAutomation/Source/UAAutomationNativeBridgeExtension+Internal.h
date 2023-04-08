/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"

#import "UAInAppMessage.h"


NS_ASSUME_NONNULL_BEGIN

@protocol UANativeBridgeExtensionDelegate;

/**
 * Automation native bridge extension.
 */
@interface UAAutomationNativeBridgeExtension : NSObject

/**
 * UAAutomationNativeBridgeExtension factory method.
 *
 * @param message The message.
 */
+ (instancetype)extensionWithMessage:(UAInAppMessage *)message;

@property (nonatomic, nonnull, readonly) id<UANativeBridgeExtensionDelegate> nativeBridgeExtension;
@end

NS_ASSUME_NONNULL_END
