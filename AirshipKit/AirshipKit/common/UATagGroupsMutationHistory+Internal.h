/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsType+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UATagGroupsMutationHistory : NSObject

+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore;

- (UATagGroupsMutation *)peekMutation:(UATagGroupsType)type;

- (UATagGroupsMutation *)popMutation:(UATagGroupsType)type;

- (void)addMutation:(UATagGroupsMutation *)mutation type:(UATagGroupsType)type;

- (void)collapseHistory:(UATagGroupsType)type;

- (void)clearHistory:(UATagGroupsType)type;

@end
