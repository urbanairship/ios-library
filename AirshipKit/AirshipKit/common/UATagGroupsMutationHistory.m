/* Copyright Urban Airship and Contributors */

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
@property (nonatomic, strong) UAPersistentQueue *pendingChannelTagGroupsMutations;
@property (nonatomic, strong) UAPersistentQueue *pendingNamedUserTagGroupsMutations;
@property (nonatomic, strong) UAPersistentQueue *tagGroupsTransactionRecords;
@end

@implementation UATagGroupsMutationHistory

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;

        self.pendingChannelTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                            key:kUAPendingChannelTagGroupsMutationsKey];
        self.pendingNamedUserTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                              key:kUAPendingNamedUserTagGroupsMutationsKey];
        self.tagGroupsTransactionRecords = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                       key:kUATagGroupsTransactionRecordsKey];
        
        [self migrateLegacyDataStoreKeys];
    }

    return self;
}

+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore];
}

- (NSString *)legacyKeyPrefixForType:(UATagGroupsType)type {
    switch(type) {
        case UATagGroupsTypeChannel:
            return kUAPushTagGroupsLegacyKeyPrefix;
        case UATagGroupsTypeNamedUser:
            return kUANamedUserTagGroupsLegacyKeyPrefix;
    }
}

- (NSString *)legacyFormattedKey:(NSString *)actionName type:(UATagGroupsType)type {
    return [NSString stringWithFormat:@"%@%@", [self legacyKeyPrefixForType:type], actionName];
}

- (NSString *)legacyAddTagsKey:(UATagGroupsType)type {
    return [self legacyFormattedKey:@"AddTagGroups" type:type];
}

- (NSString *)legacyRemoveTagsKey:(UATagGroupsType)type {
    return [self legacyFormattedKey:@"RemoveTagGroups" type:type];
}

- (NSString *)legacyMutationsKey:(UATagGroupsType)type {
    return [self legacyFormattedKey:@"TagGroupsMutations" type:type];
}

- (void)migrateLegacyDataStoreKeys {
    for (NSNumber *typeNumber in @[@(UATagGroupsTypeNamedUser), @(UATagGroupsTypeChannel)]) {
        UATagGroupsType type = typeNumber.unsignedIntegerValue;

        NSString *addTagsKey = [self legacyAddTagsKey:type];
        NSString *removeTagsKey = [self legacyRemoveTagsKey:type];
        NSString *mutationsKey = [self legacyMutationsKey:type];

        NSDictionary *addTags = [self.dataStore objectForKey:addTagsKey];
        NSDictionary *removeTags = [self.dataStore objectForKey:removeTagsKey];

        id encodedMutations = [self.dataStore objectForKey:mutationsKey];
        NSArray *mutations = encodedMutations == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:encodedMutations];

        if (addTags || removeTags) {
            UATagGroupsMutation *mutation = [UATagGroupsMutation mutationWithAddTags:addTags removeTags:removeTags];
            [self addPendingMutation:mutation type:type];
            [self.dataStore removeObjectForKey:addTagsKey];
            [self.dataStore removeObjectForKey:removeTagsKey];
        }

        if (mutations.count) {
            UAPersistentQueue *queue = [self pendingMutationsQueue:type];
            [queue addObjects:mutations];
            [self.dataStore removeObjectForKey:mutationsKey];
        }
    }
}

- (NSTimeInterval)maxSentMutationAge {
    return [self.dataStore doubleForKey:kUATagGroupsSentMutationsMaxAgeKey defaultValue:kUATagGroupsSentMutationsDefaultMaxAge];
}

- (void)setMaxSentMutationAge:(NSTimeInterval)maxAge {
    [self.dataStore setDouble:maxAge forKey:kUATagGroupsSentMutationsMaxAgeKey];
}

- (UAPersistentQueue *)pendingMutationsQueue:(UATagGroupsType)type {
    switch(type) {
        case UATagGroupsTypeChannel:
            return self.pendingChannelTagGroupsMutations;
        case UATagGroupsTypeNamedUser:
            return self.pendingNamedUserTagGroupsMutations;
    }
}

- (NSArray<UATagGroupsMutation *> *)pendingMutations {
    NSArray<UATagGroupsMutation *> *pendingChannelTagGroupMutations = (NSArray<UATagGroupsMutation *>*) [self.pendingChannelTagGroupsMutations objects];
    NSArray<UATagGroupsMutation *> *pendingNamedUserTagGroupMutations = (NSArray<UATagGroupsMutation *>*) [self.pendingNamedUserTagGroupsMutations objects];

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

- (void)addPendingMutation:(UATagGroupsMutation *)mutation type:(UATagGroupsType)type {
    [[self pendingMutationsQueue:type] addObject:mutation];
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

- (UATagGroupsMutation *)peekPendingMutation:(UATagGroupsType)type {
    return (UATagGroupsMutation *)[[self pendingMutationsQueue:type] peekObject];
}

- (UATagGroupsMutation *)popPendingMutation:(UATagGroupsType)type {
    return (UATagGroupsMutation *)[[self pendingMutationsQueue:type] popObject];
}

- (void)collapsePendingMutations:(UATagGroupsType)type {
    UAPersistentQueue *queue = [self pendingMutationsQueue:type];

    NSArray<UATagGroupsMutation *> *mutations = [[queue objects] mutableCopy];
    mutations = [UATagGroupsMutation collapseMutations:mutations];

    [queue setObjects:mutations];
}

- (void)clearPendingMutations:(UATagGroupsType)type {
    [[self pendingMutationsQueue:type] clear];
}

- (void)clearSentMutations {
    [self.tagGroupsTransactionRecords clear];
}

- (void)clearAll {
    [self clearPendingMutations:UATagGroupsTypeChannel];
    [self clearPendingMutations:UATagGroupsTypeNamedUser];
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
