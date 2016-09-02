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

#import "UAAssociatedIdentifiers.h"
#import "UAGlobal.h"

#define kUAAssociatedIdentifierIDFAKey @"com.urbanairship.idfa"
#define kUAAssociatedIdentifierVendorKey @"com.urbanairship.vendor"
#define kUAAssociatedIdentifierLimitedAdTrackingEnabledKey @"com.urbanairship.limited_ad_tracking_enabled"

@interface UAAssociatedIdentifiers()
@property (nonatomic, strong) NSMutableDictionary *mutableIDs;
@end

@implementation UAAssociatedIdentifiers

NSUInteger const UAAssociatedIdentifiersMaxCount = 100;
NSUInteger const UAAssociatedIdentifiersMaxCharacterCount = 255;

- (instancetype) init {
    self = [super init];
    if (self) {
        self.mutableIDs = [NSMutableDictionary dictionary];
    }

    return self;
}

+ (instancetype)identifiers {
    return [[UAAssociatedIdentifiers alloc] init];
}

+ (instancetype)identifiersWithDictionary:(NSDictionary *)identifiers {
    UAAssociatedIdentifiers *associatedIdentifiers = [[UAAssociatedIdentifiers alloc] init];

    for (id key in identifiers) {
        id value = identifiers[key];
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
            [associatedIdentifiers setIdentifier:value forKey:key];
        } else {
            UA_LWARN(@"Unable to create associated identifiers instance when dictionary contains a non string key/value for key: %@", key);
        }
    }

    return associatedIdentifiers;
}

- (void)setAdvertisingID:(NSString *)advertisingID {
    [self setIdentifier:advertisingID forKey:kUAAssociatedIdentifierIDFAKey];
}

- (NSString *)advertisingID {
    return [self.mutableIDs valueForKey:kUAAssociatedIdentifierIDFAKey];
}

- (void)setVendorID:(NSString *)vendorID {
    [self setIdentifier:vendorID forKey:kUAAssociatedIdentifierVendorKey];
}

- (NSString *)vendorID {
    return [self.mutableIDs valueForKey:kUAAssociatedIdentifierVendorKey];
}

- (void)setAdvertisingTrackingEnabled:(BOOL)advertisingTrackingEnabled {
    // If advertisingTrackingEnabled is `YES`, store the limitedAdTrackingEnabled value as `false`
    [self setIdentifier:(advertisingTrackingEnabled ? @"false" : @"true") forKey:kUAAssociatedIdentifierLimitedAdTrackingEnabledKey];
}

- (BOOL)advertisingTrackingEnabled {
    return ![[self.mutableIDs valueForKey:kUAAssociatedIdentifierLimitedAdTrackingEnabledKey] isEqualToString:@"true"];
}

- (void)setIdentifier:(NSString *)identifier forKey:(NSString *)key {
    if (!key) {
        return;
    }

    if (identifier) {
        [self.mutableIDs setObject:identifier forKey:key];
    } else {
        [self.mutableIDs removeObjectForKey:key];
    }
}

- (NSDictionary *)allIDs {
    return [self.mutableIDs copy];
}

@end
