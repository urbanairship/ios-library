    /*
Copyright 2009-2013 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

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



#import "UAInbox.h"

#import "UAirship.h"
#import "UAInboxDBManager.h"
#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"
#import "UAInboxMessage.h"
#import "UAUser.h"
#import "UAInboxMessageListObserver.h"

@implementation UAInbox

SINGLETON_IMPLEMENTATION(UAInbox)

#pragma mark -
#pragma mark Custom UI

static Class _uiClass;

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(INBOX_UI_CLASS);
    }
    
    if (_uiClass == nil) {
        UALOG(@"Inbox UI class not found.");
    }
	
    return _uiClass;
}

- (void)enterForeground {
    [self.messageList retrieveMessageListWithDelegate:nil];
}

- (void)userCreated {
    [self.messageList retrieveMessageListWithDelegate:nil];
}

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

#pragma mark -
#pragma mark Open API, enter/quit Inbox

+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated {
    [[[UAInbox shared] uiClass] displayInboxInViewController:parentViewController animated:animated];
}

+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController {
    [[UAInbox shared].uiClass displayMessageWithID:messageID inViewController:parentViewController];
}


+ (void)quitInbox {
    [[[UAInbox shared] uiClass] quitInbox];
}

+ (void)land {
    
    if (g_sharedUAInbox) {

        [g_sharedUAInbox.messageList removeObserver:g_sharedUAInbox.pushHandler];
        g_sharedUAInbox.messageList = nil;
        [[g_sharedUAInbox uiClass]land];
        [UAInboxMessageList land];
        
        g_sharedUAInbox = nil;
    }
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
            UA_LINFO(@"error deleting inbox cache: %@", error.description);
        }
    }
}

#pragma mark -
#pragma mark Memory management

- (id)init {
    self = [super init];
    if (self) {
        self.messageList = [UAInboxMessageList shared];
        
        [self.messageList retrieveMessageListWithDelegate:nil];
		
		self.pushHandler = [[UAInboxPushHandler alloc] init];

        [self.messageList addObserver:self.pushHandler];

       [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(enterForeground)
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

        if (![[UAUser defaultUser] defaultUserCreated]) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(userCreated)
                                                         name:UAUserCreatedNotification object:nil];
        }

        //delete legacy UAInboxCache if present
        [self deleteInboxCache];
    }

    return self;
}

- (void)dealloc {
    [self.messageList removeObserver:self.pushHandler];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.pushHandler = nil;
}


@end
