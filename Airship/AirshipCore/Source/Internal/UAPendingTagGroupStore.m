/* Copyright Airship and Contributors */

#import "UAPendingTagGroupStore+Internal.h"
#import "UAPersistentQueue+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif


#define kUAPendingChannelTagGroupsMutationsKey @"com.urbanairship.tag_groups.pending_channel_tag_groups_mutations"

@interface UAPendingTagGroupStore ()
@property (nonatomic, copy) NSString *storeKey;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAPersistentQueue *pendingTagGroupsMutations;
@end

@implementation UAPendingTagGroupStore

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;

        self.pendingTagGroupsMutations = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                                     key:kUAPendingChannelTagGroupsMutationsKey];
    }

    return self;
}

+ (instancetype)channelHistoryWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore];
}

+ (instancetype)namedUserHistoryWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore];
}

- (NSArray<UATagGroupsMutation *> *)pendingMutations {
    return (NSArray<UATagGroupsMutation *>*)[self.pendingTagGroupsMutations objects];
}

- (void)addPendingMutation:(UATagGroupsMutation *)mutation {
    [self.pendingTagGroupsMutations addObject:mutation];
}

- (UATagGroupsMutation *)peekPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations peekObject];
}

- (UATagGroupsMutation *)popPendingMutation {
    return (UATagGroupsMutation *)[self.pendingTagGroupsMutations popObject];
}

- (void)collapsePendingMutations {
    [self.pendingTagGroupsMutations collapse:^(NSArray<id<NSSecureCoding>>* objects) {
        return [UATagGroupsMutation collapseMutations:(NSArray<UATagGroupsMutation *>*)objects];
    }];
}

- (void)clearPendingMutations {
    [self.pendingTagGroupsMutations clear];
}

@end
