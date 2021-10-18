/* Copyright Airship and Contributors */

#import "UAInAppAudienceHistorian+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UAInAppAudienceRecordType) {
    UAInAppAudienceRecordTypeAttributes,
    UAInAppAudienceRecordTypeTags
};

#define kUAInAppAudienceHistorianRecordUpdates @"updates"
#define kUAInAppAudienceHistorianRecordDate @"date"
#define kUAInAppAudienceHistorianRecordType @"type"

NS_ASSUME_NONNULL_END

@interface UAInAppAudienceHistorian()

@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) id<UAContactProtocol> contact;

@property (nonatomic, strong) UADate *date;

@property (nonatomic, strong) NSMutableArray *contactRecords;
@property (nonatomic, strong) NSMutableArray *channelRecords;
@end

@implementation UAInAppAudienceHistorian

- (instancetype)initWithChannel:(UAChannel *)channel
                        contact:(id<UAContactProtocol>)contact
                           date:(UADate *)date{
    self = [super init];

    if (self) {
        self.channel = channel;
        self.contact = contact;
        self.date = date;
        self.channelRecords = [NSMutableArray array];
        self.contactRecords = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(channelAudienceUpdated:)
                                                     name:UAChannel.audienceUpdatedEvent
                                                   object:nil];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactAudienceUpdated:)
                                                     name:UAContact.audienceUpdatedEvent
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactChanged)
                                                     name:UAContact.contactChangedEvent
                                                   object:nil];
    }

    return self;
}

+ (instancetype)historianWithChannel:(UAChannel *)channel contact:(id<UAContactProtocol>)contact {
    return [[self alloc] initWithChannel:channel contact:contact date:[[UADate alloc] init]];
}

+ (instancetype)historianWithChannel:(UAChannel *)channel contact:(id<UAContactProtocol>)contact date:(UADate *)date {
    return [[self alloc] initWithChannel:channel contact:contact date:date];
}


- (void)channelAudienceUpdated:(NSNotification *)notification {
    NSArray<UAAttributeUpdate *> *attributes = [notification.userInfo objectForKey:UAChannel.audienceAttributesKey];
    if (attributes.count) {
        [self.contactRecords addObject:@{ kUAInAppAudienceHistorianRecordDate: self.date.now,
                                          kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeAttributes),
                                          kUAInAppAudienceHistorianRecordUpdates: attributes }];
    }
    
    NSArray<UATagGroupUpdate *> *tags = [notification.userInfo objectForKey:UAChannel.audienceTagsKey];
    if (tags.count) {
        [self.contactRecords addObject:@{ kUAInAppAudienceHistorianRecordDate: self.date.now,
                                          kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeTags),
                                          kUAInAppAudienceHistorianRecordUpdates: tags }];
    }
}


- (void)contactAudienceUpdated:(NSNotification *)notification {
    NSArray<UAAttributeUpdate *> *attributes = [notification.userInfo objectForKey:UAContact.attributesKey];
    if (attributes.count) {
        [self.contactRecords addObject:@{ kUAInAppAudienceHistorianRecordDate: self.date.now,
                                          kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeAttributes),
                                          kUAInAppAudienceHistorianRecordUpdates: attributes }];
    }
    
    NSArray<UATagGroupUpdate *> *tags = [notification.userInfo objectForKey:UAContact.tagsKey];
    if (tags.count) {
        [self.contactRecords addObject:@{ kUAInAppAudienceHistorianRecordDate: self.date.now,
                                          kUAInAppAudienceHistorianRecordType: @(UAInAppAudienceRecordTypeTags),
                                          kUAInAppAudienceHistorianRecordUpdates: tags }];
    }
}


- (NSArray *)updatesNewerThan:(NSDate *)date type:(UAInAppAudienceRecordType)type {
    NSMutableArray *updates = [NSMutableArray array];

    for (id record in self.combinedRecords) {
        if ([record[kUAInAppAudienceHistorianRecordType] unsignedIntValue] != type) {
            continue;
        }
        
        if ([record[kUAInAppAudienceHistorianRecordDate] compare:date] == NSOrderedAscending) {
            continue;
        }

        [updates addObjectsFromArray:record[kUAInAppAudienceHistorianRecordUpdates]];
    }

    return updates;
}

- (NSArray<UATagGroupUpdate *> *)tagHistoryNewerThan:(NSDate *)date {
    return [self updatesNewerThan:date type:UAInAppAudienceRecordTypeTags];
}

- (NSArray<UAAttributeUpdate *> *)attributeHistoryNewerThan:(NSDate *)date {
    return [self updatesNewerThan:date type:UAInAppAudienceRecordTypeAttributes];
}

- (NSArray *)combinedRecords {
    NSMutableArray *combined = [NSMutableArray array];
    [combined addObjectsFromArray:self.channelRecords];
    [combined addObjectsFromArray:self.contactRecords];
    return combined;
}

- (void)contactChanged {
    [self.contactRecords removeAllObjects];
}
@end


