/* Copyright Airship and Contributors */

#import "UATagGroupHistorian.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupHistorian()

@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) NSMutableArray<UATagGroupsTransactionRecord *> *records;

@end

@implementation UATagGroupHistorian

- (instancetype)initTagGroupHistorianWithChannel:(UAChannel *)channel namedUser:(UANamedUser *)namedUser {
    self = [super init];

    if (self) {
        self.channel = channel;
        self.namedUser = namedUser;
        self.records = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedChannelTagGroupsMutation:)
                                                     name:UAChannelUploadedTagGroupMutationNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedNamedUserTagGroupsMutation:)
                                                     name:UANamedUserUploadedTagGroupMutationNotification
                                                   object:nil];
    }

    return self;
}


- (void)uploadedChannelTagGroupsMutation:(NSNotification *)notification {

    UATagGroupsMutation *tagGroupsMutation = [notification.userInfo objectForKey:UAChannelUploadedTagGroupMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UAChannelUploadedTagGroupMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UAChannelUploadedTagGroupMutationNotificationIdentifierKey];

    if (tagGroupsMutation && date) {
        UATagGroupsTransactionRecord *record = [UATagGroupsTransactionRecord transactionRecordWithMutation:tagGroupsMutation
                                                                                                      date:date
                                                                                                      type:UATagGroupsTransactionRecordTypeChannel
                                                                                                 identifer:identifier];
        [self.records addObject:record];
    }
}

- (void)uploadedNamedUserTagGroupsMutation:(NSNotification *)notification {

    UATagGroupsMutation *tagGroupsMutation = [notification.userInfo objectForKey:UANamedUserUploadedTagGroupMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UANamedUserUploadedTagGroupMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UANamedUserUploadedTagGroupMutationNotificationIdentifierKey];

    if (tagGroupsMutation && date) {
        UATagGroupsTransactionRecord *record = [UATagGroupsTransactionRecord transactionRecordWithMutation:tagGroupsMutation
                                                                                                      date:date
                                                                                                      type:UATagGroupsTransactionRecordTypeNamedUser
                                                                                                 identifer:identifier];
        [self.records addObject:record];
    }
}

- (NSArray<UATagGroupsTransactionRecord *> *)transactionRecordsWithMaxAge:(NSTimeInterval)maxAge {
    NSArray<UATagGroupsTransactionRecord *> * records = (NSArray<UATagGroupsTransactionRecord *> *)self.records;

    records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UATagGroupsTransactionRecord *record, id bindings) {
        NSDate *now = [NSDate date];
        NSTimeInterval elapsed = [now timeIntervalSinceDate:record.date];
        return elapsed < maxAge;
    }]];

    return records;
}

- (NSArray<UATagGroupsMutation *> *)sentMutationsWithMaxAge:(NSTimeInterval)maxAge {
    NSArray<UATagGroupsTransactionRecord *> *records = [self transactionRecordsWithMaxAge:maxAge];

    NSString *namedUserIDentifier = self.namedUser.identifier;
    NSMutableArray<UATagGroupsMutation *> *mutations = [NSMutableArray array];

    for (UATagGroupsTransactionRecord *record in records) {
        // Skip known named user records with mismatched identifiers
        if (record.type == UATagGroupsTransactionRecordTypeNamedUser && ![record.identifier isEqualToString:namedUserIDentifier]) {
            continue;;
        }

        [mutations addObject:record.mutation];
    }

    return mutations;
}

- (NSDictionary *)applyMutations:(NSArray<UATagGroupsMutation *> *)mutations tags:(NSDictionary *)tags {
    for (UATagGroupsMutation *mutation in mutations) {
        tags = [mutation applyToTagGroups:tags];
    }

    return tags;
}

- (UATagGroups *)applyHistory:(UATagGroups *)tagGroups maxAge:(NSTimeInterval)maxAge {
    
    NSDictionary *tags = tagGroups.tags;
    
    // Recently uploaded mutations
    tags = [self applyMutations:[self sentMutationsWithMaxAge:maxAge] tags:tags];
    
    // Pending Channel
    tags = [self applyMutations:[self.channel pendingTagGroups] tags:tags];
    
    // Pending Named User
    tags = [self applyMutations:[self.namedUser pendingTagGroups] tags:tags];
    
    return [UATagGroups tagGroupsWithTags:tags];
}

@end
