/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAApplicationMetrics class keeps track of application-related metrics.
 */
@interface UAApplicationMetrics : NSObject

///---------------------------------------------------------------------------------------
/// @name Application Metrics Properties
///---------------------------------------------------------------------------------------

/**
 * The date of the last time the application was active.
 * Only tracked if UAFeatureInAppAutomation or UAFeatureAnalytics are enabled in the privacy manager.
 */
@property (nonatomic, readonly, strong, nullable) NSDate *lastApplicationOpenDate;

/**
 * The application's current short version string.
 */
@property (nonatomic, readonly) NSString *currentAppVersion;

/**
 * Determines whether the application's short version string has been updated.
 * Only tracked if UAFeatureInAppAutomation or UAFeatureAnalytics are enabled in the privacy manager.
 */
@property (nonatomic, readonly) BOOL isAppVersionUpdated;

@end

NS_ASSUME_NONNULL_END
