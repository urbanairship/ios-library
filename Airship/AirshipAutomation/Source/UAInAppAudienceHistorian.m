/* Copyright Airship and Contributors */

#import "UAInAppAudienceHistorian+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UAInAppAudienceRecordType) {
    UAInAppAudienceRecordTypeChannel,
    UAInAppAudienceRecordTypeNamedUser
};

#define kUAInAppAudienceHistorianRecordIdentifier @"identifier"
#define kUAInAppAudienceHistorianRecordType @"type"
#define kUAInAppAudienceHistorianRecordMutation @"mutation"
#define kUAInAppAudienceHistorianRecordDate @"date"

NS_ASSUME_NONNULL_END

@interface UAInAppAudienceHistorian()

@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) NSMutableArray *tagRecords;
@property (nonatomic, strong) NSMutableArray *attributeRecords;
@end

@implementation UAInAppAudienceHistorian

- (instancetype)initWithChannel:(UAChannel *)channel
                      namedUser:(UANamedUser *)namedUser {
    self = [super init];

    if (self) {
        self.channel = channel;
        self.namedUser = namedUser;
        self.tagRecords = [NSMutableArray array];
        self.attributeRecords = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedChannelTagGroupsMutation:)
                                                     name:UAChannelUploadedTagGroupMutationNotification
                                                   object:nil];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedChannelAttributeMutations:)
                                                     name:UAChannelUploadedAttributeMutationsNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedNamedUserTagGroupsMutation:)
                                                     name:UANamedUserUploadedTagGroupMutationNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadedNamedUserAttributeMutations:)
                                                     name:UANamedUserUploadedAttributeMutationsNotification
                                                   object:nil];
    }

    return self;
}

+ (instancetype)historianWithChannel:(UAChannel *)channel namedUser:(UANamedUser *)namedUser {
    return [[self alloc] initWithChannel:channel namedUser:namedUser];
}

- (void)uploadedChannelTagGroupsMutation:(NSNotification *)notification {
    UATagGroupsMutation *mutation = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationIdentifierKey];

    if (mutation && date && identifier) {
        [self.tagRecords addObject:@{ kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeChannel),
                                      kUAInAppAudienceHistorianRecordDate: date,
                                      kUAInAppAudienceHistorianRecordMutation: mutation,
                                      kUAInAppAudienceHistorianRecordIdentifier: identifier }];
    }
}

- (void)uploadedChannelAttributeMutations:(NSNotification *)notification {
    UAAttributePendingMutations *mutations = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UAChannelUploadedAudienceMutationNotificationIdentifierKey];

    if (mutations && date && identifier) {
        [self.attributeRecords addObject:@{ kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeChannel),
                                            kUAInAppAudienceHistorianRecordDate: date,
                                            kUAInAppAudienceHistorianRecordMutation: mutations,
                                            kUAInAppAudienceHistorianRecordIdentifier: identifier }];
    }
}

- (void)uploadedNamedUserTagGroupsMutation:(NSNotification *)notification {
    UATagGroupsMutation *mutation = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationIdentifierKey];

    if (mutation && date && identifier) {
        [self.tagRecords addObject:@{ kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeNamedUser),
                                      kUAInAppAudienceHistorianRecordDate: date,
                                      kUAInAppAudienceHistorianRecordMutation: mutation,
                                      kUAInAppAudienceHistorianRecordIdentifier: identifier }];
    }
}


- (void)uploadedNamedUserAttributeMutations:(NSNotification *)notification {
    UAAttributePendingMutations *mutations = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationMutationKey];
    NSDate *date = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationDateKey];
    NSString *identifier = [notification.userInfo objectForKey:UANamedUserUploadedAudienceMutationNotificationIdentifierKey];

    if (mutations && date && identifier) {
        [self.attributeRecords addObject:@{ kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeNamedUser),
                                            kUAInAppAudienceHistorianRecordDate: date,
                                            kUAInAppAudienceHistorianRecordMutation: mutations,
                                            kUAInAppAudienceHistorianRecordIdentifier: identifier }];
    }
}

- (NSArray *)mutationsFromRecords:(NSArray *)records newerThan:(NSDate *)date {
    NSString *namedUserIdentifier = self.namedUser.identifier;
    NSMutableArray *mutations = [NSMutableArray array];

    for (id record in records) {
        if ([record[kUAInAppAudienceHistorianRecordDate] compare:date] == NSOrderedAscending) {
            continue;
        }

        if ([record[kUAInAppAudienceHistorianRecordType] unsignedIntegerValue] == UAInAppAudienceRecordTypeNamedUser && ![record[kUAInAppAudienceHistorianRecordIdentifier] isEqualToString:namedUserIdentifier]) {
            continue;
        }

        [mutations addObject:record[kUAInAppAudienceHistorianRecordMutation]];
    }

    return mutations;
}

- (NSArray<UATagGroupsMutation *> *)tagHistoryNewerThan:(NSDate *)date {
    return [self mutationsFromRecords:self.tagRecords newerThan:date];
}

- (NSArray<UATagGroupsMutation *> *)attributeHistoryNewerThan:(NSDate *)date {
    return [self mutationsFromRecords:self.attributeRecords newerThan:date];
}

@end

