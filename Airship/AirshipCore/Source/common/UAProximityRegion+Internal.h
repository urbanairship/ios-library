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

/**
 * Maximum RSSI of the proximity region.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMaxRSSI.
*/
extern double const kUAProximityRegionMaxRSSI DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMaxRSSI.");

/**
 * Minimum RSSI of the proximity region.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinRSSI.
*/
extern double const kUAProximityRegionMinRSSI DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinRSSI.");


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
