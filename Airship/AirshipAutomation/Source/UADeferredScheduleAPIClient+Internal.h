/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UADeferredScheduleResult+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAStateOverrides+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UADeferredAPIClientResponse+Internal.h"

@class UATagGroupUpdate;
@class UAAttributeUpdate;
@class UARequestSession;
@class UARuntimeConfig;
@class UAAutomationAudienceOverrides;

NS_ASSUME_NONNULL_BEGIN

/**
 * Deferred schedule API client.
 */
@interface UADeferredScheduleAPIClient : NSObject

/**
 * UADeferredScheduleAPIClient class factory method. Used for testing.
 *
 * @param config The runtime config.
 * @param session The request session.
 * @param stateOverridesProvider The state overrides provider block.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
          stateOverridesProvider:(UAStateOverrides * (^)(void))stateOverridesProvider;

/**
 * UADeferredScheduleAPIClient class factory method.
 *
 * @param config The runtime config.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Resolves a deferred schedule.
 * @param URL The URL.
 * @param channelID The channel ID.
 * @param triggerContext The optional trigger context.
 * @param audienceOverrides The audienceOverrides overrides.
 * @param completionHandler The completion handler. The completion handler is called on an internal serial queue.
 */
- (void)resolveURL:(NSURL *)URL
         channelID:(NSString *)channelID
    triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
 audienceOverrides:(UAAutomationAudienceOverrides *)audienceOverrides
 completionHandler:(void (^)(UADeferredAPIClientResponse * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
