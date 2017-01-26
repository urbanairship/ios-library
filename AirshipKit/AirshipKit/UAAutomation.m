/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAAutomation+Internal.h"
#import "UAAnalytics+Internal.h"
#import "UAAutomationStore+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAActionScheduleData+Internal.h"

#import "UAActionSchedule+Internal.h"
#import "UAScheduleTrigger+Internal.h"

#import "UAirship.h"
#import "UAEvent.h"
#import "UARegionEvent+Internal.h"
#import "UACustomEvent+Internal.h"
#import "UAActionRunner+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAJSONPredicate.h"
#import "UAPreferenceDataStore+Internal.h"

NSUInteger const UAAutomationScheduleLimit = 100;
NSString *const UAAutomationEnabled = @"UAAutomationEnabled";

@implementation UAAutomation

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore{
    self = [super init];

    if (self) {
        self.automationStore = [UAAutomationStore automationStoreWithConfig:config];
        self.preferenceDataStore = dataStore;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }

    return self;
}

+ (instancetype)automationWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAAutomation alloc] initWithConfig:config dataStore:dataStore];
}


- (UAActionSchedule *)scheduleFromData:(UAActionScheduleData *)data {

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        NSMutableArray *triggers = [NSMutableArray array];

        for (UAScheduleTriggerData *triggerData in data.triggers) {
            UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithType:(UAScheduleTriggerType)[triggerData.type integerValue]
                                                                       goal:triggerData.goal
                                                                  predicate:[self predicateFromData:triggerData.predicateData]];

            [triggers addObject:trigger];
        }

        builder.actions = [NSJSONSerialization objectWithString:data.actions];
        builder.triggers = triggers;
        builder.group = data.group;
    }];


    return [UAActionSchedule actionScheduleWithIdentifier:data.identifier info:scheduleInfo];
}

- (UAJSONPredicate *)predicateFromData:(NSData *)data {
    if (!data) {
        return nil;
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return [UAJSONPredicate predicateWithJSON:json error:nil];
}

#pragma mark -
#pragma mark Public API

- (void)scheduleActions:(UAActionScheduleInfo *)scheduleInfo completionHandler:(void (^)(UAActionSchedule *))completionHandler {
    // Only allow valid schedules to be saved
    if (!scheduleInfo.isValid) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil);
            });
        }

        return;
    }

    [self.preferenceDataStore setBool:YES forKey:UAAutomationEnabled];

    // Delete any expired schedules before trying to save a schedule to free up the limit
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"end <= %@", [NSDate date]];
    [self.automationStore deleteSchedulesWithPredicate:predicate];

    // Create a schedule to save
    UAActionSchedule *schedule = [UAActionSchedule actionScheduleWithIdentifier:[NSUUID UUID].UUIDString info:scheduleInfo];

    // Try to save the schedule
    [self.automationStore saveSchedule:schedule limit:UAAutomationScheduleLimit completionHandler:^(BOOL success) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(success ? schedule : nil);
            });
        }
    }];
}

- (void)cancelScheduleWithIdentifier:(NSString *)identifier {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
    [self.automationStore deleteSchedulesWithPredicate:predicate];
}

- (void)cancelAll {
    [self.automationStore deleteSchedulesWithPredicate:nil];
}

- (void)cancelSchedulesWithGroup:(NSString *)group {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@", group];
    [self.automationStore deleteSchedulesWithPredicate:predicate];
}

- (void)getScheduleWithIdentifier:(NSString *)identifier completionHandler:(void (^)(UAActionSchedule *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ && end >= %@", identifier, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:UAAutomationScheduleLimit completionHandler:^(NSArray<UAActionScheduleData *> *schedulesData) {
        UAActionSchedule *schedule;
        if (schedulesData.count) {
            schedule = [self scheduleFromData:[schedulesData firstObject]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedule);
        });
    }];
}

- (void)getSchedules:(void (^)(NSArray<UAActionSchedule *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"end >= %@", [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:UAAutomationScheduleLimit completionHandler:^(NSArray<UAActionScheduleData *> *schedulesData) {
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAActionScheduleData *scheduleData in schedulesData) {
            [schedules addObject:[self scheduleFromData:scheduleData]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedules);
        });
    }];
}

- (void)getSchedulesWithGroup:(NSString *)group completionHandler:(void (^)(NSArray<UAActionSchedule *> *))completionHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"group == %@ && end >= %@", group, [NSDate date]];
    [self.automationStore fetchSchedulesWithPredicate:predicate limit:UAAutomationScheduleLimit completionHandler:^(NSArray<UAActionScheduleData *> *schedulesData) {
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAActionScheduleData *scheduleData in schedulesData) {
            [schedules addObject:[self scheduleFromData:scheduleData]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(schedules);
        });
    }];
}


#pragma mark -
#pragma mark Event listeners

- (void)didBecomeActive {
    [self enterForeground];

    // This handles the first active. enterForeground will handle future background->foreground
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)enterForeground {
    [self updateTriggersWithType:UAScheduleTriggerAppForeground argument:nil incrementAmount:1.0];
}

- (void)enterBackground {
    [self updateTriggersWithType:UAScheduleTriggerAppBackground argument:nil incrementAmount:1.0];
}

-(void)customEventAdded:(UACustomEvent *)event {
    [self updateTriggersWithType:UAScheduleTriggerCustomEventCount argument:event.payload incrementAmount:1.0];

    if (event.eventValue) {
        [self updateTriggersWithType:UAScheduleTriggerCustomEventValue argument:event.payload incrementAmount:[event.eventValue doubleValue]];
    }
}

-(void)regionEventAdded:(UARegionEvent *)event {
    UAScheduleTriggerType triggerType;

    if (event.boundaryEvent == UABoundaryEventEnter) {
        triggerType = UAScheduleTriggerRegionEnter;
    } else {
        triggerType = UAScheduleTriggerRegionExit;
    }

    [self updateTriggersWithType:triggerType argument:event.payload incrementAmount:1.0];
}

-(void)screenTracked:(NSString *)screenName {
    [self updateTriggersWithType:UAScheduleTriggerScreen argument:screenName incrementAmount:1.0];
}

- (void)updateTriggersWithType:(UAScheduleTriggerType)triggerType argument:(id)argument incrementAmount:(double)amount {
    if (![self.preferenceDataStore boolForKey:UAAutomationEnabled]) {
        return;
    }

    UA_LDEBUG(@"Updating triggers with type: %ld", (long)triggerType);
    NSDate *methodStart = [NSDate date];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type = %ld AND start <= %@", triggerType, [NSDate date]];

    [self.automationStore fetchTriggersWithPredicate:predicate completionHandler:^(NSArray<UAScheduleTriggerData *> *triggers) {
        NSMutableSet *triggeredSchedules = [NSMutableSet set];

        for (UAScheduleTriggerData *trigger in triggers) {

            UAJSONPredicate *predicate = [self predicateFromData:trigger.predicateData];
            if (predicate && argument) {
                if (![predicate evaluateObject:argument]) {
                    continue;
                }
            }

            trigger.goalProgress = @([trigger.goalProgress doubleValue] + amount);
            if ([trigger.goalProgress compare:trigger.goal] != NSOrderedAscending) {
                trigger.goalProgress = 0;
                [triggeredSchedules addObject:trigger.schedule];
            }
        }


        for (UAActionScheduleData *schedule in triggeredSchedules) {

            // If the schedule has expired, delete it
            if ([schedule.end compare:[NSDate date]] == NSOrderedAscending) {
                [schedule.managedObjectContext deleteObject:schedule];
                continue;
            }

            [UAActionRunner runActionsWithActionValues:[NSJSONSerialization objectWithString:schedule.actions]
                                             situation:UASituationAutomation
                                              metadata:nil
                                     completionHandler:^(UAActionResult *result) {
                                         UA_LINFO(@"Actions triggered for schedule: %@", schedule.identifier);
                                     }];

            if (schedule.limit > 0) {
                schedule.triggeredCount = @([schedule.triggeredCount integerValue] + 1);
                if (schedule.triggeredCount >= schedule.limit) {
                    [schedule.managedObjectContext deleteObject:schedule];
                }
            }

        }

        NSDate *methodFinish = [NSDate date];
        NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
        UA_LTRACE(@"Automation execution time: %f seconds, triggers: %ld, actions: %ld", executionTime, (unsigned long)triggers.count, (unsigned long)triggeredSchedules.count);
    }];
}

@end

