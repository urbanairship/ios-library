/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppAutomation.h"
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UASchedule.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

@class UAPreferenceDataStore;
@class UAChannel;
@class UAAnalytics;
@class UAPrivacyManager;
@class UAInAppCoreSwiftBridge;
@protocol UAFrequencyLimitManagerProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app automation manager provides a control interface for creating,
 * canceling and executing in-app automations.
 */
@interface UAInAppAutomation() 

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                    automationEngine:(UAAutomationEngine *)automationEngine
                inAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                    remoteDataClient:(UAInAppRemoteDataClient *)remoteDataClient
                           dataStore:(UAPreferenceDataStore *)dataStore
                 inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager
                             channel:(UAChannel *)channel
               frequencyLimitManager:(id<UAFrequencyLimitManagerProtocol>)frequencyLimitManager
                      privacyManager:(UAPrivacyManager *)privacyManager;

+ (instancetype)automationWithConfig:(UARuntimeConfig *)config
                inAppCoreSwiftBridge:(UAInAppCoreSwiftBridge *)inAppCoreSwiftBridge
                           dataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           analytics:(UAAnalytics *)analytics
                      privacyManager:(UAPrivacyManager *)privacyManager;

- (void)cancelSchedulesWithType:(UAScheduleType)scheduleType
              completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Get all the in-app automations.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;


@end

NS_ASSUME_NONNULL_END


