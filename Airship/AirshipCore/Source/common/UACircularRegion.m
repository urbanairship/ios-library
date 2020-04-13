/* Copyright Airship and Contributors */

#import "UACircularRegion+Internal.h"
#import "UARegionEvent+Internal.h"
#import "UAGlobal.h"

@implementation UACircularRegion

double const UACircularRegionMaxRadius = 100000; // 100 kilometers
double const UACircularRegionMinRadius = 0.1; // 100 millimeters
double const kUACircularRegionMaxRadius = UACircularRegionMaxRadius; // Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMaxRadius.
double const kUACircularRegionMinRadius = UACircularRegionMinRadius; // Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionMinRadius.

+ (nullable instancetype)circularRegionWithRadius:(NSNumber *)radius latitude:(NSNumber *)latitude longitude:(NSNumber *)longitude {

    UACircularRegion *circularRegion = [[self alloc] init];

    circularRegion.radius = radius;
    circularRegion.latitude = latitude;
    circularRegion.longitude = longitude;

    if (!circularRegion.isValid) {
        return nil;
    }

    return circularRegion;
}

- (BOOL)isValid {
    if (![UARegionEvent regionEventRadiusIsValid:self.radius]) {
        UA_LERR(@"Circular region radius must not be greater than %f meters or less than %f meters.", UACircularRegionMaxRadius, UACircularRegionMinRadius);
        return NO;
    }

    if (![UARegionEvent regionEventLatitudeIsValid:self.latitude]) {
        UA_LERR(@"Circular region latitude must not be greater than %f or less than %f degrees.", UARegionEventMaxLatitude, UARegionEventMinLatitude);
        return NO;
    }

    if (![UARegionEvent regionEventLongitudeIsValid:self.longitude]) {
        UA_LERR(@"Circular region longitude must not be greater than %f or less than %f degrees.",  UARegionEventMaxLongitude, UARegionEventMinLongitude);
        return NO;
    }

    return YES;
}

@end
