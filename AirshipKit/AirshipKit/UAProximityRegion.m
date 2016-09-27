/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAProximityRegion+Internal.h"
#import "UARegionEvent+Internal.h"
#import "UAGlobal.h"

@implementation UAProximityRegion

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
            UA_LERR(@"Proximity region latitude must not be greater than %d or less than %d degrees.", kUARegionEventMaxLatitude, kUARegionEventMinLatitude);
            return;
        }

        _latitude = latitude;
    }
}

- (void)setLongitude:(NSNumber *)longitude {
    if (longitude != _longitude) {

        if (longitude && ![UARegionEvent regionEventLongitudeIsValid:longitude]) {
            UA_LERR(@"Proximity region longitude must not be greater than %d or less than %d degrees.", kUARegionEventMaxLongitude, kUARegionEventMinLongitude);
            return;
        }

        _longitude = longitude;
    }
}

- (void)setRSSI:(NSNumber *)RSSI {
    if (RSSI != _RSSI) {

        if (RSSI && ![UARegionEvent regionEventRSSIIsValid:RSSI]) {
            UA_LERR(@"Proximity region RSSI must not be greater than %d or less than %d dBm.", kUAProximityRegionMaxRSSI, kUAProximityRegionMinRSSI);
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
        UA_LERR(@"Proximity region ID must not be greater than %d or less than %d characters in length.", kUARegionEventMaxCharacters, kUARegionEventMinCharacters);
        return NO;
    }

    return YES;
}

@end
