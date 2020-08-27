/* Copyright Airship and Contributors */

#import "UAProximityRegion.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAProximityRegion
 */
@interface UAProximityRegion ()

/**
 * Maximum RSSI of the proximity region.
 */
extern double const UAProximityRegionMaxRSSI;

/**
 * Minimum RSSI of the proximity region.
 */
extern double const UAProximityRegionMinRSSI;

///---------------------------------------------------------------------------------------
/// @name Proximity Region Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The identifier of the proximity region
 */
@property (nonatomic, copy) NSString *proximityID;

/**
 * The major of the proximity region
 */
@property (nonatomic, strong) NSNumber *major;

/**
 * The minor of the proximity region
 */
@property (nonatomic, strong) NSNumber *minor;

///---------------------------------------------------------------------------------------
/// @name Proximity Region Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Validates proximity region
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
