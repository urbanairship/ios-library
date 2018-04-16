/* Copyright 2018 Urban Airship and Contributors */

#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"

@implementation UAPreferenceDataStore(TagGroupsMutation)


- (void)setTagGroupsMutations:(NSArray<UATagGroupsMutation *> *)Mutations forKey:(NSString *)key {
    NSData *encodedMutations = [NSKeyedArchiver archivedDataWithRootObject:Mutations];
    [self setObject:encodedMutations forKey:key];
}

- (NSArray<UATagGroupsMutation *> *)tagGroupsMutationsForKey:(NSString *)key {
    id encodedMutations = [self valueForKey:key];
    if (!encodedMutations) {
        return [NSArray<UATagGroupsMutation *> array];
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:encodedMutations];
}

- (void)addTagGroupsMutation:(UATagGroupsMutation *)mutation forKey:(NSString *)key {
    id mutations = [[self tagGroupsMutationsForKey:key] mutableCopy];
    
    if (!mutations) {
        mutations = @[mutation];
    } else {
        [mutations addObject:mutation];
    }
    
    [self setTagGroupsMutations:mutations forKey:key];
}

- (nullable UATagGroupsMutation *)peekTagGroupsMutationForKey:(NSString *)key {
    id mutations = [self tagGroupsMutationsForKey:key];
    if (![mutations count]) {
        return nil;
    }
    
    return mutations[0];
}

- (UATagGroupsMutation *)popTagGroupsMutationForKey:(NSString *)key {
    id mutations = [[self tagGroupsMutationsForKey:key] mutableCopy];
    if (![mutations count]) {
        return nil;
    }
    
    id mutation = mutations[0];
    [mutations removeObjectAtIndex:0];
    
    if ([mutations count]) {
        [self setTagGroupsMutations:mutations forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
    
    return mutation;
}

- (void)collapseTagGroupsMutationForKey:(NSString *)key {
    id mutations = [[self tagGroupsMutationsForKey:key] mutableCopy];
    
    mutations = [UATagGroupsMutation collapseMutations:mutations];
    
    [self setTagGroupsMutations:mutations forKey:key];
}

- (void)migrateTagGroupSettingsForAddTagsKey:(NSString *)addTagsKey
                               removeTagsKey:(NSString *)removeTagsKey
                                      newKey:(NSString *)key {

    NSDictionary *addTags = [self objectForKey:addTagsKey];
    NSDictionary *removeTags = [self objectForKey:removeTagsKey];

    if (addTags || removeTags) {
        UATagGroupsMutation *mutation = [UATagGroupsMutation mutationWithAddTags:addTags removeTags:removeTags];
        [self addTagGroupsMutation:mutation forKey:key];

        [self removeObjectForKey:addTagsKey];
        [self removeObjectForKey:removeTagsKey];
    }
}

@end
