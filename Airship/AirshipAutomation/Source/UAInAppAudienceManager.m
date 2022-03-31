/* Copyright Airship and Contributors */

#import "UAInAppAudienceManager+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


NSTimeInterval const UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds = 60 * 10; // 10 minutes

@interface UAInAppAudienceManager ()

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAInAppAudienceHistorian *historian;
@property (nonatomic, strong) UADate *currentTime;
@property (nonatomic, strong) id<UAContactProtocol> contact;
@property (nonatomic, strong) UAChannel *channel;

@property (nonatomic, readonly) NSTimeInterval maxSentMutationAge;

@end

@implementation UAInAppAudienceManager

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                          contact:(id<UAContactProtocol>)contact
                        historian:(UAInAppAudienceHistorian *)historian
                      currentTime:(UADate *)currentTime {

    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        self.historian = historian;
        self.currentTime = currentTime;
        self.contact = contact;
        self.channel = channel;

    }

    return self;
}

+ (instancetype)managerWithConfig:(UARuntimeConfig *)config
                        dataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                        contact:(id<UAContactProtocol>)contact {

    return [[self alloc] initWithDataStore:dataStore
                                   channel:channel
                                 contact:contact
                                 historian:[UAInAppAudienceHistorian historianWithChannel:channel contact:contact]
                               currentTime:[[UADate alloc] init]];
}

+ (instancetype)managerWithDataStore:(UAPreferenceDataStore *)dataStore
                             channel:(UAChannel *)channel
                           contact:(id<UAContactProtocol>)contact
                           historian:(UAInAppAudienceHistorian *)historian
                         currentTime:(UADate *)currentTime {

    return [[self alloc] initWithDataStore:dataStore
                                   channel:channel
                                 contact:contact
                                 historian:historian
                               currentTime:currentTime];
}

- (NSArray<UATagGroupUpdate *> *)tagOverrides {
    NSDate *date = [self.currentTime.now dateByAddingTimeInterval:-UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds];
    return [self tagOverridesNewerThan:date];
}

- (NSArray<UATagGroupUpdate *> *)tagOverridesNewerThan:(NSDate *)date {
    NSMutableArray *overrides = [[self.historian tagHistoryNewerThan:date] mutableCopy];

    [overrides addObjectsFromArray:self.contact.pendingTagGroupUpdates];
    [overrides addObjectsFromArray:self.channel.pendingTagGroupUpdates];

    // Channel tags
    if (self.channel.isChannelTagRegistrationEnabled) {
        [overrides addObject:[[UATagGroupUpdate alloc] initWithGroup:@"device" tags:self.channel.tags type:UATagGroupUpdateTypeSet]];
    }

    return [UAAudienceUtils collapseTagGroupUpdates:overrides];
}

- (NSArray<UAAttributeUpdate *> *)attributeOverrides {
    NSDate *date = [self.currentTime.now dateByAddingTimeInterval:-UAInAppAudienceManagerDefaultPreferLocalAudienceDataTimeSeconds];
    NSMutableArray *overrides = [[self.historian attributeHistoryNewerThan:date] mutableCopy];

    [overrides addObjectsFromArray:self.contact.pendingAttributeUpdates];
    [overrides addObjectsFromArray:self.channel.pendingAttributeUpdates];

    return [UAAudienceUtils collapseAttributeUpdates:overrides];
}

@end

