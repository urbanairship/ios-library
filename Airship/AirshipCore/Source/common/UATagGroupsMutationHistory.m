/* Copyright Airship and Contributors */

#import "UATagGroupsMutationHistory+Internal.h"
#import "UAPersistentQueue+Internal.h"

#define kUATagGroupsSentMutationsDefaultMaxAge 60 * 60 * 24 // 1 Day

// Legacy prefix for channel tag group keys
#define kUAPushTagGroupsLegacyKeyPrefix @"UAPush"

// Legacy prefix for named user tag group keys
#define kUANamedUserTagGroupsLegacyKeyPrefix @"UANamedUser"

// Keys for pending mutations and transaction records
#define kUAPendingChannelTagGroupsMutationsKey @"com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"
#define kUAPendingNamedUserTagGroupsMutationsKey @"com.urbanairship.tag_groups.pending_named_user_tag_groups_mutations"
#define kUATagGroupsTransactionRecordsKey @"com.urbanairship.tag_groups.transaction_records"

// Max record age
#define kUATagGroupsSentMutationsMaxAgeKey @"com;urbanairship.tag_groups.transaction_records.max_age"

@interface UATagGroupsMutationHistory ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAPersistentQueue *pendingTagGroupsMutations;
@property (nonatomic, strong) UAPersistentQueue *tagGroupsTransactionRecords;
@end

@implementation UATagGroupsMutationHistory

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore keyStore:(NSString *)keyStore {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        
        self.storeKey = keyStore;

        if ([self.storeKey isEqualToString:UATagGroupsNamedUserStoreKey]) {
            self.pendingTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
            key:kUAPendingNamedUserTagGroupsMutationsKey];
        } else {
            self.pendingTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
            key:kUAPendingChannelTagGroupsMutationsKey];
        }

        self.tagGroupsTransactionRecords = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                       key:kUATagGroupsTransactionRecordsKey];
        
        [self migrateLegacyDataStoreKeys];
    }

    return self;
}

+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore keyStore:(NSString *)keyStore {
    return [[self alloc] initWithDataStore:dataStore keyStore:keyStore];
}

- (NSString *)legacyKeyPrefix {
    if ([self.storeKey isEqualToString:UATagGroupsNamedUserStoreKey]) {
        return kUANamedUserTagGroupsLegacyKeyPrefix;
    } else {
        return kUAPushTagGroupsLegacyKeyPrefix;
    }
}

- (NSString *)legacyFormattedKey:(NSString *)actionName {
    return [NSString stringWithFormat:@"%@%@", [self legacyKeyPrefix], actionName];
}

- (NSString *)legacyAddTagsKey {
    return [self legacyFormattedKey:@"AddTagGroups"];
}

- (NSString *)legacyRemoveTagsKey {
    return [self legacyFormattedKey:@"RemoveTagGroups"];
}

- (NSString *)legacyMutationsKey {
    return [self legacyFormattedKey:@"TagGroupsMutations"];
}

- (void)migrateLegacyDataStoreKeys {
    NSString *addTagsKey = [self legacyAddTagsKey];
    NSString *removeTagsKey = [self legacyRemoveTagsKey];
    NSString *mutationsKey = [self legacyMutationsKey];
    
    NSDictionary *addTags = [self.dataStore objectForKey:addTagsKey];
    NSDictionary *removeTags = [self.dataStore objectForKey:removeTagsKey];
    
    id encodedMutations = [self.dataStore objectForKey:mutationsKey];
    NSArray *mutations = encodedMutations == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:encodedMutations];
    
    if (addTags || removeTags) {
        UATagGroupsMutation *mutation = [UATagGroupsMutation mutationWithAddTags:addTags removeTags:removeTags];
        [self addPendingMutation:mutation];
        [self.dataStore removeObjectForKey:addTagsKey];
        [self.dataStore removeObjectForKey:removeTagsKey];
    }
    
    if (mutations.count) {
        [self.pendingTagGroupsMutations addObjects:mutations];
        [self.dataStore removeObjectForKey:mutationsKey];
    }
}

- (NSTimeInterval)maxSentMutationAge {
    return [self.dataStore doubleForKey:kUATagGroupsSentMutationsMaxAgeKey defaultValue:kUATagGroupsSentMutationsDefaultMaxAge];
}

- (void)setMaxSentMutationAge:(NSTimeInterval)maxAge {
    [self.dataStore setDouble:maxAge forKey:kUATagGroupsSentMutationsMaxAgeKey];
}


- (NSArray<UATagGroupsMutation *> *)pendingMutations {
    NSArray<UATagGroupsMutation *> *pendingChannelTagGroupMutations = (NSArray<UATagGroupsMutation *>*) [self.pendingTagGroupsMutations objects];
    NSArray<UATagGroupsMutation *> *pendingNamedUserTagGroupMutations = (NSArray<UATagGroupsMutation *>*) [self.pendingTagGroupsMutations objects];

    return [pendingNamedUserTagGroupMutations arrayByAddingObjectsFromArray:pendingChannelTagGroupMutations];
}

- (NSArray<UATagGroupsTransactionRecord *> *)transactionRecordsWithMaxAge:(NSTimeInterval)maxAge {
    NSArray<UATagGroupsTransactionRecord *> * records = (NSArray<UATagGroupsTransactionRecord *> *)[self.tagGroupsTransactionRecords objects];

    records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UATagGroupsTransactionRecord *record, id bindings) {
        NSDate *now = [NSDate date];
        NSTimeInterval elapsed = [now timeIntervalSinceDate:record.date];
        return elapsed < maxAge;
    }]];

    return records;
}

- (NSArray<UATagGroupsMutation *> *)sentMutationsWithMaxAge:(NSTimeInterval)maxAge {
    NSArray<UATagGroupsTransactionRecord *> *records = [self transactionRecordsWithMaxAge:maxAge];

    NSMutableArray<UATagGroupsMutation *> *mutations = [NSMutableArray array];
    for (UATagGroupsTransactionRecord *record in records) {
        [mutations addObject:record.mutation];
    }

    return mutations;
}

- (void)addPendingMutation:(UATagGroupsMutation *)mutation {
    [self.pendingTagGroupsMutations addObject:mutation];
}

- (void)cleanTransactionRecords {
    NSArray<UATagGroupsTransactionRecord *> *recentTransactions = [self transactionRecordsWithMaxAge:self.maxSentMutationAge];
    [self.tagGroupsTransactionRecords setObjects:recentTransactions];

}

- (void)addSentMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date {
    UATagGroupsTransactionRecord *record = [UATagGroupsTransactionRecord transactionRecordWithMutation:mutation date:date];
    [self.tagGroupsTransactionRecords addObject:record];

    [self cleanTransactionRecords];
}

- (UATagGroupsMutation *)peekPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations peekObject];
}

- (UATagGroupsMutation *)popPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations popObject];
}

- (void)collapsePendingMutations {

    NSArray<UATagGroupsMutation *> *mutations = [[self.pendingTagGroupsMutations objects] mutableCopy];
    mutations = [UATagGroupsMutation collapseMutations:mutations];

    [self.pendingTagGroupsMutations setObjects:mutations];
}

- (void)clearPendingMutations {
    [self.pendingTagGroupsMutations clear];
}

- (void)clearSentMutations {
    [self.tagGroupsTransactionRecords clear];
}

- (void)clearAll {
    [self clearPendingMutations];
    [self clearSentMutations];
}

- (NSDictionary *)applyMutations:(NSArray<UATagGroupsMutation *> *)mutations tags:(NSDictionary *)tags {
    for (UATagGroupsMutation *mutation in mutations) {
        tags = [mutation applyToTagGroups:tags];
    }

    return tags;
}

- (UATagGroups *)applyHistory:(UATagGroups *)tagGroups maxAge:(NSTimeInterval)maxAge {
    NSDictionary *tags = tagGroups.tags;
    tags = [self applyMutations:[self sentMutationsWithMaxAge:maxAge] tags:tags];
    tags = [self applyMutations:[self pendingMutations] tags:tags];

    return [UATagGroups tagGroupsWithTags:tags];
}

@end
