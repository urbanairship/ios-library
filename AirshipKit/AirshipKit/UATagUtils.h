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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The UATagUtils object provides an interface for creating tags.
 */
@interface UATagUtils : NSObject

/**
 * Used to trim whitespace and filter out tags with unacceptable tag length.
 *
 * @note This method is for internal use only. It is called when tags are set.
 * @param tags Tags as an NSArray.
 */
#if __has_feature(objc_generics)
+ (NSArray<NSString *> *)normalizeTags:(NSArray *)tags;
#else
+ (NSArray *)normalizeTags:(NSArray *)tags;
#endif

/**
 * Check if tags and tagGroupID are not empty.
 *
 * @note This method is for internal use only. It is called when modifying tag groups.
 * @param tags Tags as an NSArray.
 * @param tagGroup Tag group ID as an NSString.
 */
+ (BOOL)isValid:(NSArray *)tags group:(NSString *)tagGroup;

/**
 * Add tags to pending tags.
 *
 * @note This method is for internal use only. It is called when modifying tag groups.
 * @param tagsToAdd Tags to combine with pending tags.
 * @param tagGroup Tag group ID to combine with pending tags.
 * @param pendingTags The pending tags to add to.
 * @return The combined tags.
 */
+ (NSDictionary *)addPendingTags:(NSArray *)tagsToAdd group:(NSString *)tagGroup pendingTagsDictionary:(NSDictionary *)pendingTags;

/**
 * Remove tags from pending tags.
 *
 * @note This method is for internal use only. It is called when modifying tag groups.
 * @param tagsToRemove Tags to remove from pending tags.
 * @param tagGroup Tag groupID to combine with pending tags.
 * @param pendingTags The pending tags to remove tags from.
 * @return The combined tags.
 */
+ (NSDictionary *)removePendingTags:(NSArray *)tagsToRemove group:(NSString *)tagGroup pendingTagsDictionary:(NSDictionary *)pendingTags;

@end

NS_ASSUME_NONNULL_END
