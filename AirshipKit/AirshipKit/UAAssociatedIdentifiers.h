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

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines analytics identifiers to be associated with
 * the device.
 */
@interface UAAssociatedIdentifiers : NSObject

/**
 * Maximum number of associated IDs that can be set.
 */
extern NSUInteger const UAAssociatedIdentifiersMaxCount;

/**
 * Character limit for associated IDs or keys.
 */
extern NSUInteger const UAAssociatedIdentifiersMaxCharacterCount;

/**
 * Factory method to create an empty identifiers object.
 * @return The created associated identifiers.
 */
+ (instancetype)identifiers;


/**
 * Factory method to create an associated identifiers instance with a dictionary
 * of custom identifiers (containing strings only).
 * @return The created associated identifiers.
 */
+ (instancetype)identifiersWithDictionary:(NSDictionary<NSString *, NSString *> *)identifiers;

/**
 * The advertising ID.
 */
@property (nonatomic, copy, nullable) NSString *advertisingID;

/**
 * The application's vendor ID.
 */
@property (nonatomic, copy, nullable) NSString *vendorID;

/**
 * Indicates whether the user has limited ad tracking.
 */
@property (nonatomic, assign) BOOL advertisingTrackingEnabled;

/**
 * A map of all the associated identifiers.
 */
@property (nonatomic, readonly) NSDictionary *allIDs;

/**
 * Sets an identifier mapping.
 * @param identifier The value of the identifier, or `nil` to remove the identifier.
 * @parm key The key for the identifier
 */
- (void)setIdentifier:(nullable NSString *)identifier forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
