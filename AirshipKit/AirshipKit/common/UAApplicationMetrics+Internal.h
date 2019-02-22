/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAApplicationMetrics.h"
#import "UADate+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to Application Metrics
 */
@interface UAApplicationMetrics ()

///---------------------------------------------------------------------------------------
/// @name Application Metrics Internal Properties
///---------------------------------------------------------------------------------------

@property (nonatomic, strong, nullable) NSDate *lastApplicationOpenDate;

///---------------------------------------------------------------------------------------
/// @name Application Metrics Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Application metrics factory method.
 * @param dataStore The dataStore.
 * @return An application metrics instance.
 */
+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Application metrics factory method. Used for testing.
 * @param dataStore The dataStore.
 * @param notificationCenter The notification center.
 * @param date The date.
 * @return An application metrics instance.
 */
+ (instancetype)applicationMetricsWithDataStore:(UAPreferenceDataStore *)dataStore
                             notificationCenter:(NSNotificationCenter *)notificationCenter
                                           date:(UADate *)date;

@end

NS_ASSUME_NONNULL_END
