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
#import "UAInboxURLCache.h"
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
    [self.messageList retrieveMessageList];
}

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

#pragma mark -
#pragma mark Open API, enter/quit Inbox

+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated {
    //if configured to use the inbox cache, swap it in here
    @synchronized(self) {
        if (g_sharedUAInbox.shouldUseInboxCache) {
            [NSURLCache setSharedURLCache:[UAInbox shared].inboxCache];
        }
    }
    [[[UAInbox shared] uiClass] displayInboxInViewController:parentViewController animated:animated];
}

+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController {
    [[UAInbox shared].uiClass displayMessageWithID:messageID inViewController:parentViewController];
}


+ (void)quitInbox {
    [[[UAInbox shared] uiClass] quitInbox];
    //swap out the inbox cache if it's currently in place
    //(the value of shouldUseInboxCache may have changed, but we'll want to swap it out regardles
    @synchronized(self) {
        if ([[NSURLCache sharedURLCache] isEqual:g_sharedUAInbox.inboxCache]) {
            [NSURLCache setSharedURLCache:[UAInbox shared].clientCache];
        }
    }
}

+ (void)land {
    
    if (g_sharedUAInbox) {

        [g_sharedUAInbox.messageList removeObserver:g_sharedUAInbox.pushHandler];
        g_sharedUAInbox.messageList = nil;
        [[g_sharedUAInbox uiClass]land];
        [UAInboxMessageList land];
        
        [g_sharedUAInbox release];
        g_sharedUAInbox = nil;
    }
}

#pragma mark -
#pragma mark Memory management

- (id)init {
    self = [super init];
    if (self) {
        // create the DB and clear out legacy info
        // prior to creating the new caches directory
        [UAInboxDBManager shared];

        self.clientCache = [NSURLCache sharedURLCache];

        //use the inbox cache by default
        self.shouldUseInboxCache = YES;
        [self initInboxCache];
        
        self.messageList = [UAInboxMessageList shared];
        
        [self.messageList retrieveMessageList];
		
		self.pushHandler = [[[UAInboxPushHandler alloc] init] autorelease];

        [self.messageList addObserver:self.pushHandler];

       [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(enterForeground)
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];

    }

    return self;
}

- (void)initInboxCache {

    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAInboxCache"];
    NSError *error;

    [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                              withIntermediateDirectories:YES
                                               attributes:nil error:&error];

    self.inboxCache = [[[UAInboxURLCache alloc] initWithMemoryCapacity:1024*1024
                                                          diskCapacity:10*1024*1024
                                                              diskPath:diskCachePath] autorelease];
}

- (void)setShouldUseInboxCache:(BOOL)shouldUseInboxCache {
    //sync on the class object so that we can be consistent with
    //display/quitInbox
    @synchronized([self class]) {
        _shouldUseInboxCache = shouldUseInboxCache;
        if (shouldUseInboxCache) {
            if (!self.inboxCache) {
                [self initInboxCache];
            }
        } else {
            self.inboxCache = nil;
        }
    }
}

- (void)dealloc {
    [self.messageList removeObserver:self.pushHandler];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.clientCache = nil;
    self.inboxCache = nil;
    self.pushHandler = nil;

    [super dealloc];
}

@end
