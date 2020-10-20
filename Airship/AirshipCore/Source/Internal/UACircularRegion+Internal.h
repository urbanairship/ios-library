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
