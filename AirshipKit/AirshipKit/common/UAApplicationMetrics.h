/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
 */
@property (nonatomic, readonly, strong, nullable) NSDate *lastApplicationOpenDate;

/**
 * The application's current short version string.
 */
@property (nonatomic, readonly) NSString *currentAppVersion;

/**
 * Determines whether the application's short version string has been updated.
 */
@property (nonatomic, readonly) BOOL isAppVersionUpdated;

@end

NS_ASSUME_NONNULL_END
