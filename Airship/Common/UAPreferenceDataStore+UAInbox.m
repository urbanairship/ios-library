//
//  UAPreferenceDataStore+MessageInbox.m
//  testApp
//
//  Created by Monish Syed on 3/23/15.
//  Copyright (c) 2015 Neulion. All rights reserved.
//

#import "UAPreferenceDataStore+UAInbox.h"
#import "UAirship+Internal.h"

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";

@implementation UAPreferenceDataStore (UAInbox)

- (NSString *)inboxLastModifiedForUser:(NSString *)userName {
  return [[UAirship shared].dataStore
          stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userName]];
}

- (void)setInboxLastModified:(NSString *)lastModified forUser:(NSString *)userName {
  [[UAirship shared].dataStore
   setValue:lastModified
   forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userName]];
}

@end
