/* Copyright 2017 Urban Airship and Contributors */

#import "UAProximityRegion.h"

#define kUAProximityRegionMaxRSSI 100 // 100 dBm
#define kUAProximityRegionMinRSSI -100 // -100 dBm

NS_ASSUME_NONNULL_BEGIN

@interface UAProximityRegion ()

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

/**
 * Validates proximity region
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
