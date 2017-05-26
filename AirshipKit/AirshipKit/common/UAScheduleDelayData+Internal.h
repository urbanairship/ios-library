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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UAActionScheduleData;
@class UAScheduleDelayConditionsData;
@class UAScheduleTriggerData;

NS_ASSUME_NONNULL_BEGIN

/**
 * CoreData class representing the backing data for
 * a UAScheduleDelayData.
 *
 * This class should not ordinarily be used directly.
 */
@interface UAScheduleDelayData : NSManagedObject

///---------------------------------------------------------------------------------------
/// @name Schedule Delay Data Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Minimum amount of time to wait in seconds before the schedule actions are able to execute.
 */
@property (nullable, nonatomic, retain) NSNumber *seconds;

/**
 * Specifies the name of an app screen that the user must currently be viewing before the
 * the schedule's actions are able to be executed. Specifying a screen requires the application
 * to make use of UAAnalytic's screen tracking method `trackScreen:`.
 */
@property (nullable, nonatomic, retain) NSString *screen;

/**
 * Specifies the ID of a region that the device must currently be in before the schedule's
 * actions are able to be executed. Specifying regions requires the application to add UARegionEvents
 * to UAAnalytics.
 */
@property (nullable, nonatomic, retain) NSString *regionID;

/**
 * Specifies the app state that is required before the schedule's actions are able to execute.
 * Defaults to `UAScheduleDelayAppStateAny`.
 */
@property (nullable, nonatomic, retain) NSNumber *appState;

/**
 * The action schedule data.
 */
@property (nullable, nonatomic, retain) UAActionScheduleData *schedule;

/**
 * The cancellation triggers.
 */
@property (nullable, nonatomic, retain) NSSet<UAScheduleTriggerData *> *cancellationTriggers;

@end

NS_ASSUME_NONNULL_END
