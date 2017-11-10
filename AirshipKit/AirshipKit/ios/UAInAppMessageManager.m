/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageAdapter.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSTimeInterval const FetchRetryDelayMS = 30000;
NSTimeInterval const DefaultMessageDisplayInterval = 5000;
NSTimeInterval const MaxSchedules = 200;

@interface UAInAppMessageManager ()

@property(nonatomic, assign) BOOL isCurrentMessagePrepared;

@property(nonatomic, assign) BOOL isDisplayLocked;

@property(nonatomic, strong, nullable) NSDictionary *adapterFactories;

@property(nonatomic, strong, nullable) UAInAppMessage *currentMessage;

@property(nonatomic, strong, nullable) id<UAInAppMessageAdapter> currentAdapter;

@property(nonatomic, strong, nullable) UAAutomationEngine *automationEngine;

@end

@implementation UAInAppMessageManager

+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine {
    return [[UAInAppMessageManager alloc] initWithAutomationEngine:automationEngine];
}

+ (instancetype)managerWithConfig:(UAConfig *)config storeName:(NSString *)storeName {
    return [[UAInAppMessageManager alloc] initWithConfig:config storeName:storeName];
}

- (instancetype)initWithConfig:(UAConfig *)config storeName:(NSString *)storeName {
    self = [super init];

    if (self) {
        self.automationEngine = [UAAutomationEngine automationEngineWithStoreName:storeName scheduleLimit:MaxSchedules];
        self.displayInterval = DefaultMessageDisplayInterval;
    }

    return self;
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine {
    self = [super init];

    if (self) {
        self.automationEngine = automationEngine;
        self.displayInterval = DefaultMessageDisplayInterval;
    }

    return self;
}

- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {

    }];
}

- (void)cancelMessage:(UAInAppMessage *)message {
    [self.automationEngine cancelSchedulesWithGroup:message.identifier];
}

- (void)cancelMessageWithScheduleID:(NSString *)scheduleID {
    [self.automationEngine cancelScheduleWithIdentifier:scheduleID];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

- (void)setFactoryBlock:(id<UAInAppMessageAdapter> (^)(NSString* displayType))factory
         forDisplayType:(NSString *)displayType {
    NSMutableDictionary *adapterFactories;

    if (!self.adapterFactories) {
        adapterFactories = [NSMutableDictionary dictionary];
    } else {
        adapterFactories = [NSMutableDictionary dictionaryWithDictionary:self.adapterFactories];
    }

    [adapterFactories setObject:factory forKey:displayType];
    self.adapterFactories = [NSDictionary dictionaryWithDictionary:adapterFactories];
}

- (nullable id<UAInAppMessageAdapter>)adapterForDisplayType:(NSString *)displayType {
    if (!self.adapterFactories) {
        return nil;
    }
    id<UAInAppMessageAdapter> (^factory)(NSString *) = [self.adapterFactories objectForKey:displayType];

    if (!factory) {
        return nil;
    }

    return factory(displayType);
}

- (void)unlockDisplayAfter:(NSTimeInterval)interval {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.isDisplayLocked = false;
        [self.automationEngine scheduleConditionsChanged];
    });
}

- (void)lockDisplay {
    self.isDisplayLocked = true;
}

- (BOOL)isScheduleReadyToExecute:(UASchedule *)schedule {
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        return NO;
    }

    // If the display is locked via timer return no
    if (self.isDisplayLocked) {
        return NO;
    }

    if (!self.currentAdapter) {
        if (!self.adapterFactories) {
            return NO;
        }

        UAInAppMessageScheduleInfo *info = [self inAppScheduleInfoWithSchedule:schedule];
        self.currentMessage = info.message;

        id<UAInAppMessageAdapter> adapter = [self adapterForDisplayType:info.message.displayType];
        self.currentAdapter = adapter;

        // If no adapter factory available for specified displayType return NO
        if (!adapter) {
            return NO;
        }

        [adapter prepare:^{
            self.isCurrentMessagePrepared = YES;
            [self.automationEngine scheduleConditionsChanged];
        }];

        return NO;
    }

    if (!self.isCurrentMessagePrepared) {
        return NO;
    }

    // If the adapter is created and prepare has completed then return YES
    return YES;
}

- (UAInAppMessageScheduleInfo *)inAppScheduleInfoWithSchedule:(UASchedule *)schedule {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;

    NSDictionary *data = [NSJSONSerialization objectWithString:info.data];

    UAInAppMessage *message = [UAInAppMessage messageWithJSON:data];
    info.message = message;

    return info;
}

- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler {
    UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
    self.currentMessage = info.message;

    id<UAInAppMessageAdapter> adapter = [self adapterForDisplayType:info.message.displayType];
    self.currentAdapter = adapter;

    if (adapter) {
        [adapter display:^{
            self.currentAdapter = nil;
            self.currentMessage = nil;
            // Lock Display
            [self lockDisplay];
            // Start timer to unlock display after display interval
            [self unlockDisplayAfter:self.displayInterval];
        }];
    } else {
        [self unlockDisplayAfter:0];
    }
}

@end

NS_ASSUME_NONNULL_END
