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

#import "NSManagedObjectContext+UAAdditions.h"
#import "UAAutomationStore+Internal.h"
#import "UAActionScheduleData+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAActionSchedule.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAirship.h"
#import "UAJSONPredicate.h"
#import "UAConfig.h"
#import "UAUtils.h"

@interface UAAutomationStore ()
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@end

NSString *const UAAutomationStoreFileFormat = @"Automation-%@.sqlite";

@implementation UAAutomationStore


- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];

    if (self) {
        NSString *storeName = [NSString stringWithFormat:UAAutomationStoreFileFormat, config.appKey];
        NSURL *modelURL = [[UAirship resources] URLForResource:@"UAAutomation" withExtension:@"momd"];
        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                     concurrencyType:NSPrivateQueueConcurrencyType
                                                                            storeName:storeName];
    }

    return self;
}

+ (instancetype)automationStoreWithConfig:(UAConfig *)config {
    return [[UAAutomationStore alloc] initWithConfig:config];
}

- (BOOL)saveContext {
    NSError *error;
    [self.managedContext save:&error];
    if (error) {
        UA_LERR(@"Error saving context %@", error);
        return NO;
    }
    return YES;
}

#pragma mark -
#pragma mark Data Access

- (void)saveSchedule:(UAActionSchedule *)schedule limit:(NSUInteger)limit completionHandler:(void (^)(BOOL))completionHandler {
    [self.managedContext performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAActionScheduleData"];
        NSUInteger count = [self.managedContext countForFetchRequest:request error:nil];
        if (count >= limit) {
            UA_LERR(@"Max schedule limit reached. Unable to save new schedule.");
            completionHandler(NO);
            return;
        }

        NSMutableSet *triggers = [NSMutableSet set];
        for (UAScheduleTrigger *trigger in schedule.info.triggers) {
            UAScheduleTriggerData *triggerData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleTriggerData"
                                                                               inManagedObjectContext:self.managedContext];
            triggerData.type = @(trigger.type);
            triggerData.goal = trigger.goal;
            triggerData.start = schedule.info.start;

            if (trigger.predicate) {
                triggerData.predicateData = [NSJSONSerialization dataWithJSONObject:trigger.predicate.payload options:0 error:nil];
            }

            [triggers addObject:triggerData];
        }

        UAActionScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAActionScheduleData"
                                                                           inManagedObjectContext:self.managedContext];

        scheduleData.identifier = schedule.identifier;
        scheduleData.limit = @(schedule.info.limit);
        scheduleData.actions = [NSJSONSerialization stringWithObject:schedule.info.actions];
        scheduleData.group = schedule.info.group;
        scheduleData.triggers = triggers;
        scheduleData.start = schedule.info.start;
        scheduleData.end = schedule.info.end;

        completionHandler([self saveContext]);
    }];
}

- (void)deleteSchedulesWithPredicate:(NSPredicate *)predicate {
    [self.managedContext performBlock:^{

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAActionScheduleData"];
        request.predicate = predicate;

        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];

        NSError *error;
        [self.managedContext executeRequest:deleteRequest error:&error];
        if (error) {
            UA_LERR(@"Error deleting entities %@", error);
            return;
        }

        [self saveContext];
    }];
}

- (void)fetchSchedulesWithPredicate:(NSPredicate *)predicate limit:(NSUInteger)limit completionHandler:(void (^)(NSArray<UAActionScheduleData *> *))completionHandler {
    [self.managedContext performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAActionScheduleData"];
        request.predicate = predicate;
        request.fetchLimit = limit;

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];

        if (error) {
            UA_LERR(@"Error fetching schedules %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self saveContext];
        }

    }];
}

- (void)fetchTriggersWithPredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *))completionHandler {
    [self.managedContext performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"UAScheduleTriggerData"];
        request.predicate = predicate;

        NSError *error;
        NSArray *result = [self.managedContext executeFetchRequest:request error:&error];
        if (error) {
            UA_LERR(@"Error fetching triggers %@", error);
            completionHandler(@[]);
        } else {
            completionHandler(result);
            [self saveContext];
        }
    }];
}


@end
