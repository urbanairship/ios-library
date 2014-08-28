/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

/**
 * Autogenerate a set of tags with
 * the following flags.
 */
typedef NS_OPTIONS(NSInteger, UATagType) {
    /**
     * Full Time Zone: "America/Los_Angeles"
     */
    UATagTypeTimeZone             = 1 << 0,

    /**
     * Abbreviated Time Zone: "PST" Note: Contains DST info and abbreviations
     * may conflict with other time zones.
     */
    UATagTypeTimeZoneAbbreviation = 1 << 1,

    /**
     * Language Code, with prefix: "language_en"
     */
    UATagTypeLanguage             = 1 << 2,

    /**
     * Country Code, with prefix: "country_us"
     */
    UATagTypeCountry              = 1 << 3,

    /**
     * Device type: iPhone, iPad or iPod
     */
    UATagTypeDeviceType           = 1 << 4
};

/**
 * The UATagUtils object provides an interface for creating tags.
 */
@interface UATagUtils : NSObject {

}

/**
 * Creates an autoreleased NSArray containing tags specified in the
 * tags parameter, a bit field accepting UATagType flags.
 * @param tags to create
 * @return The tags as an NSArray.
 */
+ (NSArray *)createTags:(UATagType) tags;

@end
