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
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UATagGroupsMutation+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Category methods to save and return tag mutations.
 */
@interface UAPreferenceDataStore(TagGroupsMutation)

/**
 * Adds a tag mutation to the array of saved mutations.
 * @param mutation The mutation to add.
 * @param atBeginning If the mutation should be inserted at the front of the array or not.
 * @param key The datastore key.
 */
- (void)addTagGroupsMutation:(UATagGroupsMutation *)mutation atBeginning:(BOOL)atBeginning forKey:(NSString *)key;


/**
 * Polls and removes the first mutation from the array of pending mutations.
 * @param key The datastore key.
 * @return The first mutation, or nil if no mutations are available.
 */
- (nullable UATagGroupsMutation *)pollTagGroupsMutationForKey:(NSString *)key;

/**
 * Migrates pending add and remove tag group changes to an array of mutations.
 * @param addTagsKey The data store key for pending add tag changes.
 * @param removeTagsKey The data store key for pending remove tag changes.
 * @param key The data store key to store the migrated mutations.
 */
- (void)migrateTagGroupSettingsForAddTagsKey:(NSString *)addTagsKey
                               removeTagsKey:(NSString *)removeTagsKey
                                      newKey:(NSString *)key;


@end

NS_ASSUME_NONNULL_END
