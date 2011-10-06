    /*
Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#import "UA_ASINetworkQueue.h"
#import "UA_ASIHTTPRequest.h"

#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"
#import "UAInboxURLCache.h"
#import "UAInboxMessage.h"
#import "UAUser.h"

#import "UAInboxMessageListObserver.h"

//weak link to this notification since it doesn't exist prior to iOS 4
UIKIT_EXTERN NSString* const UIApplicationWillEnterForegroundNotification __attribute__((weak_import));

UA_VERSION_IMPLEMENTATION(UAInboxVersion, UA_VERSION)

@implementation UAInbox

@synthesize messageList;
@synthesize jsDelegate;
@synthesize pushHandler;
@synthesize clientCache;
@synthesize inboxCache;

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
    [messageList retrieveMessageList];
}

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

#pragma mark -
#pragma mark Open API, enter/quit Inbox

+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated {
    [NSURLCache setSharedURLCache:[UAInbox shared].inboxCache];
    [[[UAInbox shared] uiClass] displayInbox:viewController animated:animated];
}

+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID {
    [[[UAInbox shared] uiClass] displayMessage:(UIViewController *)viewController message:messageID];
}


+ (void)quitInbox {
    [[[UAInbox shared] uiClass] quitInbox];
    [NSURLCache setSharedURLCache:[UAInbox shared].clientCache];
}

+ (void)land {
    // Update application badge number
	[UAInbox shared].messageList = nil;
	
    [[[UAInbox shared] uiClass] land];
	
    RELEASE_SAFELY(g_sharedUAInbox);
    [UAInboxMessageList land];
}

#pragma mark -
#pragma mark Memory management

- (id)init {
    if (self = [super init]) {

        /* Using custom URLCache */
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        //append bundle name to cache directory to make it app-unique
        NSString *cacheDirectory = [[paths objectAtIndex:0]stringByAppendingPathComponent:bundleName];
        NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAInboxCache"];
        NSError *error;

        [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:&error];
        
		self.inboxCache = [[[UAInboxURLCache alloc] initWithMemoryCapacity:1024*1024
                                                                diskCapacity:10*1024*1024
                                                                    diskPath:diskCachePath] autorelease];
        self.clientCache = [NSURLCache sharedURLCache];
        
        self.messageList = [UAInboxMessageList shared];
        
        [messageList retrieveMessageList];
		
		pushHandler = [[UAInboxPushHandler alloc] init];
        
        IF_IOS4_OR_GREATER(
                           
           if (&UIApplicationDidEnterBackgroundNotification != NULL) {
               
               [[NSNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(enterForeground)
                                                            name:UIApplicationWillEnterForegroundNotification
                                                          object:nil];
           }
        );
        
    }

    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(clientCache);
    RELEASE_SAFELY(inboxCache);
	RELEASE_SAFELY(pushHandler);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

@end
