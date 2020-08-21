/* Copyright Airship and Contributors */

#import "UAInAppAudienceHistorian+Internal.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"
#import "UATagGroupsTransactionRecord+Internal.h"

@interface UAInAppAudienceHistorian()

@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) NSMutableArray<UATagGroupsTransactionRecord *> *records;

@end

@implementation UAInAppAudienceHistorian

- (instancetype)initWithChannel:(UAChannel *)channel namedUser:(UANamedUser *)namedUser {
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

+ (instancetype)historianWithChannel:(UAChannel *)channel namedUser:(UANamedUser *)namedUser {
    return [[self alloc] initWithChannel:channel namedUser:namedUser];
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

- (NSArray<UATagGroupsMutation *> *)mutationsFromRecords:(NSArray *)records newerThan:(NSDate *)date {
    NSString *namedUserIdentifier = self.namedUser.identifier;
    NSMutableArray *mutations = [NSMutableArray array];

    for (UATagGroupsTransactionRecord *record in records) {
        if ([record.date compare:date] == NSOrderedAscending) {
            continue;
        }

        if (record.type == UATagGroupsTransactionRecordTypeNamedUser && ![record.identifier isEqualToString:namedUserIdentifier]) {
            continue;
        }

        [mutations addObject:record.mutation];
    }

    return mutations;
}

- (NSArray<UATagGroupsMutation *> *)tagHistoryNewerThan:(NSDate *)date {
    return [self mutationsFromRecords:self.records newerThan:date];
}

@end
