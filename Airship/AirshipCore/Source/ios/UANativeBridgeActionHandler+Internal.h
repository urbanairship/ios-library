/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAJavaScriptCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Action command handler for the native bridge.
 */
@interface UANativeBridgeActionHandler : NSObject

/**
 * Runs actions for a command.
 * @param command The action command.
 * @param metadata The action metadata.
 * @param completionHandler The completion handler with optional script to evaluate in the web view..
 */
- (void)runActionsForCommand:(UAJavaScriptCommand *)command
                    metadata:(NSDictionary *)metadata
           completionHandler:(void (^)(NSString * __nullable))completionHandler;

/**
 * Checks if a command defines an action.
 * @param command The command.
 * @return `YES` if the command is either `run-actions`, `run-action`, or `run-action-cb`, otherwise `NO`.
 */
+ (BOOL)isActionCommand:(UAJavaScriptCommand *)command;

@end

NS_ASSUME_NONNULL_END
