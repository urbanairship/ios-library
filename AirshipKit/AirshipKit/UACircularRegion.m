/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UACircularRegion+Internal.h"
#import "UARegionEvent+Internal.h"
#import "UAGlobal.h"

@implementation UACircularRegion

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
        UA_LERR(@"Circular region radius must not be greater than %d meters or less than %f meters.", kUACircularRegionMaxRadius, kUACircularRegionMinRadius);
        return NO;
    }

    if (![UARegionEvent regionEventLatitudeIsValid:self.latitude]) {
        UA_LERR(@"Circular region latitude must not be greater than %d or less than %d degrees.", kUARegionEventMaxLatitude, kUARegionEventMinLatitude);
        return NO;
    }

    if (![UARegionEvent regionEventLongitudeIsValid:self.longitude]) {
        UA_LERR(@"Circular region longitude must not be greater than %d or less than %d degrees.", kUARegionEventMaxLongitude, kUARegionEventMinLongitude);
        return NO;
    }

    return YES;
}

@end
