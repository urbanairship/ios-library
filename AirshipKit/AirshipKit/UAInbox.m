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

#import "UAInbox+Internal.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUser.h"
#import "UAInboxMessageList+Internal.h"

@implementation UAInbox

- (void)dealloc {
    [self.client.session cancelAllRequests];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithUser:(UAUser *)user config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.user = user;
        self.client = [UAInboxAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config] user:user dataStore:dataStore];
        self.messageList = [UAInboxMessageList messageListWithUser:self.user client:self.client config:config];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];

        if (!self.user.isCreated) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(userCreated)
                                                         name:UAUserCreatedNotification
                                                       object:nil];
        }

        [self.messageList loadSavedMessages];

        // Register for didBecomeActive to refresh the inbox on the first active
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];



        // delete legacy UAInboxCache if present
        [self deleteInboxCache];
    }
    
    return self;
}

+ (instancetype) inboxWithUser:(UAUser *)user config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInbox alloc] initWithUser:user config:config dataStore:dataStore];
}

- (void)enterForeground {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}


- (void)didBecomeActive {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];

    // We only want to refresh the inbox on the first active. enterForeground will
    // handle any background->foreground inbox refresh
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)userCreated {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

//note: this is for deleting the UAInboxCache from disk, which is no longer in use.
- (void)deleteInboxCache{
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAInboxCache"];

    NSFileManager *fm = [NSFileManager defaultManager];

    if ([fm fileExistsAtPath:diskCachePath]) {
        NSError *error = nil;
        [fm removeItemAtPath:diskCachePath error:&error];
        if (error) {
            UA_LTRACE(@"Error deleting inbox cache: %@", error.description);
        }
    }
}

@end
