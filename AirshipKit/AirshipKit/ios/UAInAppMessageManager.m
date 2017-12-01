/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAGlobal.h"
#import "UAConfig.h"

NS_ASSUME_NONNULL_BEGIN

NSTimeInterval const FetchRetryDelayMS = 30000;
NSTimeInterval const DefaultMessageDisplayInterval = 5000;
NSTimeInterval const MaxSchedules = 200;
NSString *const UAInAppAutomationStoreFileFormat = @"In-app-automation-%@.sqlite";

@interface UAInAppMessageManager ()

@property(nonatomic, assign) BOOL isCurrentMessagePrepared;

@property(nonatomic, assign) BOOL isDisplayLocked;

@property(nonatomic, strong, nullable) NSDictionary *adapterFactories;

@property(nonatomic, strong, nullable) NSString *currentScheduleID;

@property(nonatomic, strong, nullable) id<UAInAppMessageAdapterProtocol> currentAdapter;

@property(nonatomic, strong, nullable) UAAutomationEngine *automationEngine;

@end

@implementation UAInAppMessageManager

+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInAppMessageManager alloc] initWithAutomationEngine:automationEngine dataStore:dataStore];
}

+ (instancetype)managerWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInAppMessageManager alloc] initWithConfig:config dataStore:dataStore];
}

- (instancetype)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithDataStore:dataStore];

    if (self) {
        NSString *storeName = [NSString stringWithFormat:UAInAppAutomationStoreFileFormat, config.appKey];
        self.automationEngine = [UAAutomationEngine automationEngineWithStoreName:storeName scheduleLimit:MaxSchedules paused:self.componentEnabled];
        self.displayInterval = DefaultMessageDisplayInterval;
    }

    return self;
}

- (instancetype)initWithAutomationEngine:(UAAutomationEngine *)automationEngine dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.automationEngine = automationEngine;
        self.displayInterval = DefaultMessageDisplayInterval;
    }

    return self;
}

- (void)scheduleMessageWithScheduleInfo:(UAInAppMessageScheduleInfo *)scheduleInfo
                      completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine schedule:scheduleInfo completionHandler:completionHandler];;
}

- (void)cancelMessageWithID:(NSString *)identifier {
    [self.automationEngine cancelSchedulesWithGroup:identifier];
}

- (void)cancelMessageWithScheduleID:(NSString *)scheduleID {
    [self.automationEngine cancelScheduleWithIdentifier:scheduleID];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

- (void)setFactoryBlock:(id<UAInAppMessageAdapterProtocol> (^)(NSString* displayType))factory
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

- (nullable id<UAInAppMessageAdapterProtocol>)adapterForDisplayType:(NSString *)displayType {
    if (!self.adapterFactories) {
        return nil;
    }
    id<UAInAppMessageAdapterProtocol> (^factory)(NSString *) = [self.adapterFactories objectForKey:displayType];

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
        UAInAppMessageScheduleInfo *info = (UAInAppMessageScheduleInfo *)schedule.info;
        id<UAInAppMessageAdapterProtocol> adapter = [self adapterForDisplayType:info.message.displayType];

        // If no adapter factory available for specified displayType return NO
        if (!adapter) {
            return NO;
        }

        self.currentAdapter = adapter;
        self.currentScheduleID = schedule.identifier;

        UA_WEAKIFY(self);
        [self.currentAdapter prepare:^{
            UA_STRONGIFY(self);

            self.isCurrentMessagePrepared = YES;
            [self.automationEngine scheduleConditionsChanged];
        }];

        return NO;
    }

    if (![schedule.identifier isEqualToString:self.currentScheduleID]) {
        return NO;
    }

    return self.isCurrentMessagePrepared;
}

- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler {
    // Lock Display
    [self lockDisplay];

    UA_WEAKIFY(self);
    [self.currentAdapter display:^{
        UA_STRONGIFY(self);
        self.currentAdapter = nil;
        self.currentScheduleID = nil;
        // Start timer to unlock display after display interval
        [self unlockDisplayAfter:self.displayInterval];
        completionHandler();
    }];
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, resume automation engine
        [self.automationEngine resume];
    } else {
        // if component was enabled and is now disabled, pause automation engine
        [self.automationEngine pause];
    }
}


@end

NS_ASSUME_NONNULL_END
