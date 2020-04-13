/* Copyright Airship and Contributors */

#import "UACircularRegion.h"

NS_ASSUME_NONNULL_BEGIN

@interface UACircularRegion ()

/**
 * Maximum radius of the circular region.
 */
extern double const UACircularRegionMaxRadius;

/**
 * Minimum radius of the circular region.
 */
extern double const UACircularRegionMinRadius;

/**
 * Maximum radius of the circular region.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMaxRadius.
*/
extern double const kUACircularRegionMaxRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMaxRadius.");

/**
 * Minimum radius of the circular region.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMinRadius.
*/
extern double const kUACircularRegionMinRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMinRadius.");

///---------------------------------------------------------------------------------------
/// @name Circular Region Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The latitude of the circular region's center
 */
@property (nonatomic, strong) NSNumber *latitude;
/**
 * The longitude of the circular region's center
 */
@property (nonatomic, strong) NSNumber *longitude;
/**
 * The circular region's radius in meters
 */
@property (nonatomic, strong) NSNumber *radius;

///---------------------------------------------------------------------------------------
/// @name Circular Region Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Validates circular region
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
