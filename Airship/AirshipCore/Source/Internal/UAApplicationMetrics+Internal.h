/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAApplicationMetrics.h"
#import "UADate.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPrivacyManager.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to Application Metrics
 */
@interface UAApplicationMetrics ()


///---------------------------------------------------------------------------------------
/// @name Application Metrics Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Application metrics factory method.
 * @param dataStore The dataStore.
 * @param privacyManager The privacy manager.
 * @return An application metrics instance.
 */
+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Application metrics factory method. Used for testing.
 * @param dataStore The dataStore.
 * @param privacyManager The privacy manager.
 * @param notificationCenter The notification center.
 * @param date The date.
 * @return An application metrics instance.
 */
+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore
                                 privacyManager:(UAPrivacyManager *)privacyManager
                             notificationCenter:(NSNotificationCenter *)notificationCenter
                                           date:(UADate *)date;

@end

NS_ASSUME_NONNULL_END
