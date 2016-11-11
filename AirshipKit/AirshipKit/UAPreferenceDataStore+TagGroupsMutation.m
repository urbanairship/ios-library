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

#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"

@implementation UAPreferenceDataStore(TagGroupsMutation)


- (void)setTagGroupsMutations:(NSArray<UATagGroupsMutation *> *)Mutations forKey:(NSString *)key {
    NSData *encodedMutations = [NSKeyedArchiver archivedDataWithRootObject:Mutations];
    [self setObject:encodedMutations forKey:key];
}

- (NSArray<UATagGroupsMutation *> *)tagGroupsMutationsForKey:(NSString *)key {
    id encodedMutations = [self valueForKey:key];
    if (!encodedMutations) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedMutations];
}

- (void)addTagGroupsMutation:(UATagGroupsMutation *)mutation atBeginning:(BOOL)atBeginning forKey:(NSString *)key {
    id Mutations = [[self tagGroupsMutationsForKey:key] mutableCopy];

    if (!Mutations) {
        Mutations = @[mutation];
    } else if (atBeginning) {
        [Mutations insertObject:mutation atIndex:0];
    } else {
        [Mutations addObject:mutation];
    }

    Mutations = [UATagGroupsMutation collapseMutations:Mutations];
    [self setTagGroupsMutations:Mutations forKey:key];
}

- (UATagGroupsMutation *)pollTagGroupsMutationForKey:(NSString *)key {
    id Mutations = [[self tagGroupsMutationsForKey:key] mutableCopy];
    if (![Mutations count]) {
        return nil;
    }

    id mutation = Mutations[0];
    [Mutations removeObjectAtIndex:0];

    if ([Mutations count]) {
        [self setTagGroupsMutations:Mutations forKey:key];
    } else {
        [self removeObjectForKey:key];
    }

    return mutation;
}

- (void)migrateTagGroupSettingsForAddTagsKey:(NSString *)addTagsKey
                               removeTagsKey:(NSString *)removeTagsKey
                                      newKey:(NSString *)key {

    NSDictionary *addTags = [self objectForKey:addTagsKey];
    NSDictionary *removeTags = [self objectForKey:removeTagsKey];

    if (addTags || removeTags) {
        UATagGroupsMutation *mutation = [UATagGroupsMutation mutationWithAddTags:addTags removeTags:removeTags];
        [self addTagGroupsMutation:mutation atBeginning:YES forKey:key];

        [self removeObjectForKey:addTagsKey];
        [self removeObjectForKey:removeTagsKey];
    }
}

@end
