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
 * Defines changes to perform on tag groups.
 */
@interface UATagGroupsMutation : NSObject

/**
 * Factory method to define tags to be added to a tag group.
 * @param tags The tags to be added.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToAddTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Factory method to define tags to be removed from a tag group.
 * @param tags The tags to be removed.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToRemoveTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Factory method to define tags to be set to a tag group.
 * @param tags The tags to be set.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToSetTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Factory method to define a tag mutation with dictionaries of tag group
 * changes to add and remove.
 * @param addTags A dictionary of tag groups to tags to add.
 * @param removeTags A dictionary of tag groups to tags to remove.
 * @return The mutation.
 */
+ (instancetype)mutationWithAddTags:(nullable NSDictionary *)addTags
                         removeTags:(nullable NSDictionary *)removeTags;

/**
 * Collapses an array of tag group mutations to either 1 or 2 mutations.
 *
 * Set tags will always be in its own mutation.
 * Add and remove will try to collapse into a set if available.
 * Adds will be removed from any remove changes, and vice versa.
 *
 * @param mutations The mutations to collapse.
 * @return An array of collapsed mutations.
 */
+ (NSArray<UATagGroupsMutation *> *)collapseMutations:(NSArray<UATagGroupsMutation *> *)mutations;


/**
 * The mutation payload for `UATagGroupsAPIClient`.
 * @return A JSON safe dictionary to be used in a request body.
 */
- (NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
