/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>

@class UAActionSchedule;
@class UAActionScheduleData;
@class UAScheduleTriggerData;
@class UAConfig;

/**
 * Manager class for the Automation CoreData store.
 */
@interface UAAutomationStore : NSObject

/**
 * Factory method for automation store.
 *
 * @param config The Urban Airship config.
 * @return Automation store.
 */
+ (instancetype)automationStoreWithConfig:(UAConfig *)config;

/**
 * Saves the UAActionSchedule to the data store.
 *
 * @param schedule The schedule to save.
 * @param limit The max number of schedules to allow.
 * @param completionHandler Completion handler when the operation is finished. `YES` if the
 * schedule was saved, `NO` if the schedule failed to save or the data store contains
 * more schedules then the specified limit.
 */
- (void)saveSchedule:(UAActionSchedule *)schedule limit:(NSUInteger)limit completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Deletes schedules from the data store.
 *
 * @param predicate The predicate matcher.
 */
- (void)deleteSchedulesWithPredicate:(NSPredicate *)predicate;


/**
 * Fetches schedule data from the data store. The schedule data can only be modified
 * in the completion handler.
 *
 * @param predicate The predicate matcher.
 * @param limit The request's limit
 * @param completionHandler Completion handler with an array of the matching schedule data.
 */
- (void)fetchSchedulesWithPredicate:(NSPredicate *)predicate limit:(NSUInteger)limit completionHandler:(void (^)(NSArray<UAActionScheduleData *> *))completionHandler;

/**
 * Fetches trigger data from the data store. The trigger data can only be modified
 * in the completion handler.
 *
 * @param predicate The predicate matcher.
 * @param completionHandler Completion handler with an array of the matching trigger data.
 */
- (void)fetchTriggersWithPredicate:(NSPredicate *)predicate completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *))completionHandler;



@end
