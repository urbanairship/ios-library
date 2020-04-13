/* Copyright Airship and Contributors */

#import "UAProximityRegion+Internal.h"
#import "UARegionEvent+Internal.h"
#import "UAGlobal.h"

@implementation UAProximityRegion

double const UAProximityRegionMaxRSSI = 100; // 100 dBm
double const UAProximityRegionMinRSSI = -100; // -100 dBm
double const kUAProximityRegionMaxRSSI = UAProximityRegionMaxRSSI; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMaxRSSI.
double const kUAProximityRegionMinRSSI = UAProximityRegionMinRSSI; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinRSSI.

+ (instancetype)proximityRegionWithID:(NSString *)proximityID major:(NSNumber *)major minor:(NSNumber *)minor {

    UAProximityRegion *proximityRegion = [[self alloc] init];

    proximityRegion.major = major;
    proximityRegion.minor = minor;
    proximityRegion.proximityID = proximityID;

    if (!proximityRegion.isValid) {
        return nil;
    }

    return proximityRegion;
}

- (void)setLatitude:(NSNumber *)latitude {
    if (latitude != _latitude) {

        if (latitude && ![UARegionEvent regionEventLatitudeIsValid:latitude]) {
            UA_LERR(@"Proximity region latitude must not be greater than %f or less than %f degrees.", UARegionEventMaxLatitude, UARegionEventMinLatitude);
            return;
        }

        _latitude = latitude;
    }
}

- (void)setLongitude:(NSNumber *)longitude {
    if (longitude != _longitude) {

        if (longitude && ![UARegionEvent regionEventLongitudeIsValid:longitude]) {
            UA_LERR(@"Proximity region longitude must not be greater than %f or less than %f degrees.", UARegionEventMaxLongitude, UARegionEventMinLongitude);
            return;
        }

        _longitude = longitude;
    }
}

- (void)setRSSI:(NSNumber *)RSSI {
    if (RSSI != _RSSI) {

        if (RSSI && ![UARegionEvent regionEventRSSIIsValid:RSSI]) {
            UA_LERR(@"Proximity region RSSI must not be greater than %f or less than %f dBm.", UAProximityRegionMaxRSSI, UAProximityRegionMinRSSI);
            return;
        }

        _RSSI = RSSI;
    }
}

- (BOOL)isValid {
    if ((self.latitude && !self.longitude) || (!self.latitude && self.longitude)) {
        UA_LERR(@"A proximity region's latitude and longitude must both be set.");
        return NO;
    }

    if (!self.minor || self.minor.intValue < 0 || self.minor.intValue > UINT16_MAX) {
        UA_LERR(@"Minor cannot be nil, less than zero or greater than 65535.");
        return NO;
    }

    if (!self.major || self.major.intValue < 0 || self.major.intValue > UINT16_MAX) {
        UA_LERR(@"Major cannot be nil, less than zero or greater than 65535.");
        return NO;
    }

    if (![UARegionEvent regionEventCharacterCountIsValid:self.proximityID]) {
        UA_LERR(@"Proximity region ID must not be greater than %ld or less than %ld characters in length.", (unsigned long) UARegionEventMaxCharacters, (unsigned long) UARegionEventMinCharacters);
        return NO;
    }

    return YES;
}

@end
