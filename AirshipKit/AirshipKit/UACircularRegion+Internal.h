/* Copyright 2017 Urban Airship and Contributors */

#import "UACircularRegion.h"

#define kUACircularRegionMaxRadius 100000 // 100 kilometers
#define kUACircularRegionMinRadius .1 // 100 millimeters

NS_ASSUME_NONNULL_BEGIN

@interface UACircularRegion ()

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

/**
 * Validates circular region
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
