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
#import "UAInboxURLCache.h"
#import "UAInboxMessage.h"
#import "UAUser.h"
#import "UA_ASINetworkQueue.h"
#import "UA_ASIHTTPRequest.h"
#import "UAInboxMessageListObserver.h"

UA_VERSION_IMPLEMENTATION(UAInboxVersion, UA_VERSION)

@implementation UAInbox

@synthesize activeInbox;
@synthesize jsDelegate;
@synthesize pushHandler;
@synthesize clientCache, inboxCache;

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

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
	[[[UAInbox shared] uiClass] setRuniPhoneTargetOniPad:value];
}

+ (void)addAuthToWebRequest:(NSMutableURLRequest*)requestObj {
    NSString *username = [UAUser defaultUser].username;
    NSString *password = [UAUser defaultUser].password;
    NSString *authString = UA_base64EncodedStringFromData([[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding]);
	
    authString = [NSString stringWithFormat: @"Basic %@", authString];
    [requestObj setValue:authString forHTTPHeaderField:@"Authorization"];
}

#pragma mark -
#pragma mark Open API, enter/quit Inbox

+ (void)setInbox:(UAInboxMessageList *)inbox {
	if([UAInbox shared].activeInbox != inbox) {
		[UAInbox shared].activeInbox = inbox;	
	}
}

+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated {
	if([UAInbox shared].activeInbox == nil) {
		[UAInbox shared].activeInbox = [UAInboxMessageList defaultInbox];
	}
	
    [[[UAInbox shared] uiClass] displayInbox:viewController animated:animated];

    [[UAInbox shared].activeInbox retrieveMessageList];
	
    [NSURLCache setSharedURLCache:[UAInbox shared].inboxCache];
}

+ (void)displayInboxOnLoad:(UAInboxMessageList *)inbox {
	[[[UAInbox shared] uiClass] displayInboxOnLoad:inbox];
}

+(void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID {
    [[[UAInbox shared] uiClass] displayMessage:viewController message:messageID];
}


+ (void)quitInbox {
    [[[UAInbox shared] uiClass] quitInbox];
    [NSURLCache setSharedURLCache:[UAInbox shared].clientCache];
}

+ (void) land {
    // Update application badge number
	[UAInbox shared].activeInbox = nil;
	
    [[[UAInbox shared] uiClass] land];
	
    RELEASE_SAFELY(g_sharedUAInbox);
    [UAInboxMessageList land];
}

#pragma mark -
#pragma mark Memory management

- (id)init {
    if (self = [super init]) {

        /* Using custom URLCache */
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachesDirectory = [paths objectAtIndex:0];
        NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cachesDirectory, @"UAInboxCache"];
        NSError *error;

        [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:&error];
        
		self.inboxCache = [[[UAInboxURLCache alloc] initWithMemoryCapacity:1024*1024
                                                                diskCapacity:10*1024*1024
                                                                    diskPath:diskCachePath] autorelease];
        self.clientCache = [NSURLCache sharedURLCache];
        
		if([UAInbox shared].activeInbox == nil) {
			[UAInbox shared].activeInbox = [UAInboxMessageList defaultInbox];
		}
		
		pushHandler = [[UAInboxPushHandler alloc] init];
    }

    return self;
}


- (void)dealloc {
    RELEASE_SAFELY(clientCache);
    RELEASE_SAFELY(inboxCache);
	RELEASE_SAFELY(pushHandler);

    [super dealloc];
}

@end
