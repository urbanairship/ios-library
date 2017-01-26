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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A UAProximityRegion defines a proximity region with an identifier, major and minor.
 */
@interface UAProximityRegion : NSObject

/**
 * The proximity region's latitude in degress.
 */
@property (nonatomic, strong, nullable) NSNumber *latitude;

/**
 * The proximity region's longitude in degrees.
 */
@property (nonatomic, strong, nullable) NSNumber *longitude;

/**
 * The proximity region's received signal strength indication in dBm.
 */
@property (nonatomic, strong, nullable) NSNumber *RSSI;

/**
 * Factory method for creating a proximity region.
 *
 * @param proximityID The ID of the proximity region.
 * @param major The major.
 * @param minor The minor.
 *
 * @return Proximity region object or `nil` if error occurs.
 */
+ (nullable instancetype)proximityRegionWithID:(NSString *)proximityID
                                         major:(NSNumber *)major
                                         minor:(NSNumber *)minor;

@end

NS_ASSUME_NONNULL_END
