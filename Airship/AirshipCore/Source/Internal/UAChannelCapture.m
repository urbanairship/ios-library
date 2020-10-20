/* Copyright Airship and Contributors */

#import "UAChannelCapture+Internal.h"
#import "UAChannel.h"
#import "UARuntimeConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAAppStateTracker.h"
#import "UADate.h"

static NSUInteger const UAChannelCaptureKnocksToTriggerChannelCapture = 6;
static NSTimeInterval const UAChannelCaptureKnocksMaxTimeSeconds = 30;
static NSTimeInterval const UAChannelCaptureKnocksPasteboardExpirationSeconds = 60;

@interface UAChannelCapture()
@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADate *date;

@property (nonatomic, strong) NSMutableArray<NSDate *> *knockTimes;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@end

@implementation UAChannelCapture

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       channel:(UAChannel *)channel
                     dataStore:(UAPreferenceDataStore *)dataStore
            notificationCenter:(NSNotificationCenter *)notificationCenter
                          date:(UADate *)date {
    self = [super init];
    if (self) {
        self.config = config;
        self.channel = channel;
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
        self.date = date;

        self.knockTimes = [NSMutableArray array];
        self.enabled = config.channelCaptureEnabled;

        [self.notificationCenter addObserver:self
                                    selector:@selector(applicationDidTransitionToForeground)
                                        name:UAApplicationDidTransitionToForeground
                                      object:nil];
    }

    return self;
}

+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                               dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAChannelCapture alloc] initWithConfig:config
                                            channel:channel
                                          dataStore:dataStore
                                 notificationCenter:[NSNotificationCenter defaultCenter]
                                               date:[[UADate alloc] init]];
}

+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter
                                    date:(UADate *)date{
    return [[UAChannelCapture alloc] initWithConfig:config
                                            channel:channel
                                          dataStore:dataStore
                                    notificationCenter:notificationCenter
                                               date:date];
}

- (void)applicationDidTransitionToForeground {
    if (!self.enabled) {
        return;
    }
    
    // save time of transition
    if (self.knockTimes.count >= UAChannelCaptureKnocksToTriggerChannelCapture) {
        [self.knockTimes removeObjectAtIndex:0];
    }
    [self.knockTimes addObject:[self.date now]];
    
    if (self.knockTimes.count < UAChannelCaptureKnocksToTriggerChannelCapture) {
        return;
    };
    
    if ([self.knockTimes[UAChannelCaptureKnocksToTriggerChannelCapture - 1] timeIntervalSinceDate:self.knockTimes[0]] > UAChannelCaptureKnocksMaxTimeSeconds) {
        return;
    };
         
    [self.knockTimes removeAllObjects];

    if (!self.channel.identifier) {
        UA_LDEBUG(@"The channel ID does not exist.");
    }

    UA_LDEBUG(@"Setting pasteboard with channel identifier = %@", self.channel.identifier);
    NSString *channelForPasteboard = (self.channel.identifier) ? [NSString stringWithFormat:@"ua:%@", self.channel.identifier] : @"ua:";
    [[UIPasteboard generalPasteboard] setItems:@[@{UIPasteboardTypeAutomatic: channelForPasteboard}]
                                       options:@{UIPasteboardOptionExpirationDate: [[self.date now] dateByAddingTimeInterval:UAChannelCaptureKnocksPasteboardExpirationSeconds]}];
}

@end


