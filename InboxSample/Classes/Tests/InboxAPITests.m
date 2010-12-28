/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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
#import "InboxAPITests.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAUser.h"
#import "InboxTestPushHandler.h"
#import "ASIHTTPRequest+UATest.h"
#import "UA_SBJSON.h"
#import "UAKeychainUtils.h"

@implementation InboxAPITests

BOOL defaultInboxFinished;
BOOL messageListLoaded;
BOOL messageReceived;
NSDictionary *messageData;
int messageCount;

- (void) dealloc {
    RELEASE_SAFELY(messageData);
    RELEASE_SAFELY(TEST_DEVICE_TOKEN);
    [super dealloc];
}

- (void)setUpClass {
    // Mock the device token
    TEST_DEVICE_TOKEN = nil;
    NSString *path = [[NSBundle mainBundle]
                      pathForResource:@"AirshipConfig" ofType:@"plist"];
    if (path != nil){
        NSMutableDictionary *config = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];
        TEST_DEVICE_TOKEN = [[config objectForKey:@"TEST_DEVICE_TOKEN"] retain];
    }
}

- (void)setUp {
    UALOG(@"Setup");
    defaultInboxFinished = NO;
    messageListLoaded = NO;
    messageReceived = NO;
    RELEASE_SAFELY(messageData);
    [UA_ASIHTTPRequest clearSession];
    [UAirship takeOff:@"YOUR_APP_KEY" identifiedBy:@"YOUR_APP_SECRET"];

    // Remove any currently registered user.
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[[UAirship shared] appId]];
    [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];

    if (TEST_DEVICE_TOKEN == nil){
        GHFail(@"Need to set TEST_DEVICE_TOKEN in AirshipConfig.plist");
    }

    // Thanks to Rob Napier: http://stackoverflow.com/questions/918997/how-do-i-convert-nsstring-with-hexvalue-to-binary-char/919075#919075
    char binChars[32];
    const char *hexChars = [TEST_DEVICE_TOKEN UTF8String];
    NSUInteger hexLen = strlen(hexChars);
    const char *nextHex = hexChars;
    char *nextChar = binChars;
    for (NSUInteger i = 0; i < hexLen - 1; i+=2) {
        sscanf(nextHex, "%2x", (unsigned int *)nextChar);
        nextHex += 2;
        nextChar++;
    }

    NSString *token = [[[NSString alloc] initWithCharacters:(const unichar *)binChars length:16] autorelease];

    NSData *dataToken = [token dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    [UA_ASIHTTPRequest clearSession];
    [[UAirship shared] registerDeviceToken:dataToken];
    messageCount = 1;
}

- (void)tearDown {
    UALOG(@"UAInbox API TestCase tear down");
    [NSClassFromString(@"UAInbox") land];
    [UAUser land];
}

- (BOOL)shouldRunOnMainThread {
    // It is necessary to run the tests on the main thread, so that any failures
    // in the push handler will result in a test failure, rather than an unhandled
    // exception.
    return YES;
}

#pragma mark -
#pragma mark Test Helper Methods

- (void)spinRunThreadWithTimeOut:(int)seconds finishedFlag:(BOOL *)finished processingString:(NSString *)processing {
    UALOG(@"Keeping run thread alive for time: %d", seconds);
    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!(*finished) && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"%@", processing);
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
}

- (void)createDefaultInbox {
    defaultInboxFinished = NO;
    [[UAUser defaultUser] addObserver:[UAInboxMessageList defaultInbox]];
    [[UAInboxMessageList defaultInbox] addObserver:self];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&defaultInboxFinished processingString:@"Waiting for inboxUser..."];
}

// Helper method, thanks to http://www.iphonedevsdk.com/forum/iphone-sdk-development/33029-reverse-string.html#post140824
-(NSString *) reverseString:(NSString *)toReverse {
    NSMutableString *reversedStr;
    int len = [toReverse length];

    reversedStr = [NSMutableString stringWithCapacity:len];
    while (len > 0) {
        [reversedStr appendString:
         [NSString stringWithFormat:@"%C", [toReverse characterAtIndex:--len]]];
    }

    return reversedStr;
}

#pragma mark -
#pragma mark Inbox Callback

-(void)inboxCreatedWithUser:(NSString*)user andPassword:(NSString*)password{
    UALOG(@"Test inbox has been created with user/pass: %@, %@", [UAUser defaultUser].username, [UAUser defaultUser].password);
    GHAssertNotNil([UAUser defaultUser], @"Oh no, the user is nil!");
    GHAssertNotNil([UAUser defaultUser].username, @"Oh no, the user is nil!");
    GHAssertEqualStrings([UAUser defaultUser].username, user, @"The default inbox should have the same user as passed into the callback");
    GHAssertNotNil([UAUser defaultUser].password, @"Oh no, the password is nil!");
    GHAssertEqualStrings([UAUser defaultUser].password, password, @"The default inbox should have the same password as passed into the callback");
    defaultInboxFinished = YES;
}

-(void)inboxError:(NSString*)message{
    GHFail(@"Error creating inbox");
    defaultInboxFinished = YES;
}

#pragma mark -
#pragma mark Test creating inbox methods

- (void)testCreateDefaultInbox {
    UALOG(@"Testing Default Inbox");
    [self createDefaultInbox];
    GHAssertNotNil([UAUser defaultUser].username, @"Inbox user is still nil.  We timed out!  :(");
}

#pragma mark Test retrieving messages methods

- (void)testRetrieveMessageList {
    UALOG(@"Testing getting message list");
    // Make sure the test class is an observer
    [self createDefaultInbox];

    [[UAInboxMessageList defaultInbox] retrieveMessageList];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&messageListLoaded processingString:@"Waiting for message list to load..."];
    GHAssertTrue(messageListLoaded, @"Message list not loaded.  We timed out!  :(");
}

-(void)messageListLoaded{
    UALOG(@"Message list has loaded");
    GHAssertNotNil([UAInboxMessageList defaultInbox].messages, @"Oh no, the messages list is nil!");
    GHAssertEquals([[UAInboxMessageList defaultInbox].messages count], (NSUInteger)messageCount,
                   @"Expecting the default message to be in the newly created inbox");
    messageListLoaded = YES;
}

-(void)inboxLoadFailed {
    GHFail(@"Error loading inbox");
    defaultInboxFinished = YES;
    messageListLoaded = YES;
}

#pragma mark Test send/receive message

-(void)testMessageSend {
#if TARGET_IPHONE_SIMULATOR
    GHFail(@"Cannot test sending/receiving push nofications from the Simulator");
#endif

    [self createDefaultInbox];

    messageData = [[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:@"New Message!" forKey:@"alert"] forKey:@"aps"], @"push",
                    [NSArray arrayWithObject:[UAUser defaultUser].username], @"users",
                    @"Test Message", @"title",
                    @"This is a message sent from tests", @"message",
                    nil] retain];

    [[InboxTestPushHandler shared] pushMessageData:messageData delegate:self selector:@selector(receivedSentMessage:)];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&messageReceived processingString:@"Waiting for message to be received..."];
    GHAssertTrue(messageReceived, @"Message not received.  We timed out!  :(");
}

- (void)receivedSentMessage:(UAInboxMessage *)message {
    UALOG(@"Received the push notification callback");
    GHAssertNotNil(message, @"The message given to the callback is nil!  :(");
    GHAssertNotNil(messageData, @"Message data is nil.  Something went wrong between sending the message and receiving the callback");
    GHAssertEqualStrings(message.title, [messageData objectForKey:@"title"], @"Message titles don't match");

    // Could also test the body here, but needs another request to the server.

    messageReceived = YES;
    RELEASE_SAFELY(messageData);
}

#pragma mark Test set alias

- (void)testSetAlias {
    UALOG(@"Testing setting alias");

    [self createDefaultInbox];


    [[UAInboxMessageList defaultInbox] modifyInboxAlias:@"Test Alias"];

    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([UAUser defaultUser].alias == nil && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for alias to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertNotNil([UAUser defaultUser].alias, @"Alias is still nil.  We timed out! :(");
    GHAssertEqualStrings([UAUser defaultUser].alias, @"Test Alias", @"Alias has not been set.");

    [[UAInboxMessageList defaultInbox] modifyInboxAlias:@"Test Alias 2"];

    giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while (![[UAUser defaultUser].alias isEqual:@"Test Alias 2"] && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for alias to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
    GHAssertEqualStrings([UAUser defaultUser].alias, @"Test Alias 2", @"Alias has not been changed.  We timed out! :(");

}

#pragma mark Test set alias and tags

- (void)testTagsAndAliases {
    UALOG(@"Test tags and aliases");

    [self createDefaultInbox];

    NSSet *tags = [NSSet setWithObjects:@"a", @"b", nil];
    [[UAInboxMessageList defaultInbox] modifyInboxAlias:nil tags:tags];

    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([[UAUser defaultUser].tags count] == 0 && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for tags to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertNotNil([UAUser defaultUser].tags, @"Tags are nil. :(");
    GHAssertEqualObjects([UAUser defaultUser].tags, tags, @"Tags are not correct.");

    [[UAInboxMessageList defaultInbox] modifyInboxAlias:@"Test Alias"];

    giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([UAUser defaultUser].alias == nil && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for alias to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertNotNil([UAUser defaultUser].alias, @"Alias not set.  We timed out! :(");
    GHAssertNotNil([UAUser defaultUser].tags, @"Tags are nil after setting alias.");
    GHAssertEqualObjects([UAUser defaultUser].tags, tags, @"Tags are not correct after setting alias");

    tags = [NSSet setWithObjects:@"a", @"c", @"d", nil];
    [[UAInboxMessageList defaultInbox] modifyInboxAlias:@"Test Alias" tags:tags];

    giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([[UAUser defaultUser].tags count] == 2 && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for tags to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertEqualObjects([UAUser defaultUser].tags, tags, @"Tags are not correct after setting new tags");
    GHAssertNotNil([UAUser defaultUser].alias, @"Alias nil after setting new tags.");
    GHAssertEqualStrings([UAUser defaultUser].alias, @"Test Alias", @"Alias not correct after setting new tags.");

    // Check against data on the server to make sure it got set there as well as on the client

    NSString *url = [NSString stringWithFormat:@"%@/api/user/%@", [UAirship shared].server, [UAUser defaultUser].username];
    UA_ASIHTTPRequest *userReq = [UA_ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
    userReq.username = [UAirship shared].appId;
    userReq.password = [UAirship shared].appSecret;

    [userReq startSynchronous];

    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSDictionary* jsonResponse = [parser objectWithString: [userReq responseString]];
    UALOG(@"Response status code/desc = %d %@", userReq.responseStatusCode, userReq.responseStatusMessage);
    UALOG(@"Response string: %@", [userReq responseString]);
    [parser release];

    NSArray *tagsArray = [jsonResponse objectForKey:@"tags"];
    GHAssertNotNil(tagsArray, @"Tags are nil on server");
    GHAssertEqualObjects([NSSet setWithArray:tagsArray], tags, @"Tags returned from server is not correct");
    NSString *alias = [jsonResponse objectForKey:@"alias"];
    GHAssertNotNil(alias, @"Alias is nil on the server. :(");
    GHAssertEqualStrings(alias, @"Test Alias", @"Alias is incorrect on the server.");
}

#pragma mark Test tag creation and usage

- (void)testATagCreationAndUsage {
    UALOG(@"Testing tag creation and usage.");

    UALOG(@"******* Phase 1 ********");

    [self createDefaultInbox];

    NSMutableSet *tags = [NSMutableSet set];
    [tags addObject:@"testTag1"];
    [[UAInboxMessageList defaultInbox] modifyInboxAlias:nil tags:tags];

    GHAssertFalse([[UAUser defaultUser].tags isEqualToSet:tags], @"Tags shouldn't be created now.");
    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while (([[UAUser defaultUser].tags count] == 0)
           && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for tags to be set...");
        NSDate* loopIntervalDate = [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
    GHAssertTrue([[UAUser defaultUser].tags isEqualToSet:tags], @"Tags should be ready now.");
    // The first mail inbox contains only one message now.
    NSMutableDictionary *firstMailboxDictionary = [[NSUserDefaults standardUserDefaults]
                                                   objectForKey:[[UAirship shared] appId]];

    UALOG(@"******* Phase 2 ********");

    [self tearDown];
    [self setUp];
    [[NSUserDefaults standardUserDefaults] setObject:firstMailboxDictionary forKey:[[UAirship shared] appId]];
    [self testRetrieveMessageList];
    [self tearDown];
    [self setUp];

    //Create another inbox
    [self createDefaultInbox];
    [[UAInboxMessageList defaultInbox] modifyInboxAlias:nil tags:tags];

    GHAssertFalse([[UAUser defaultUser].tags isEqualToSet:tags], @"Tags shouldn't be created now.");
    giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while (([[UAUser defaultUser].tags count] == 0)
           && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for alias to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
    GHAssertTrue([[UAUser defaultUser].tags isEqualToSet:tags], @"Tags should be ready now.");

    UALOG(@"******* Phase 3 ********");

    // test push with tags
#if TARGET_IPHONE_SIMULATOR
    GHFail(@"Cannot test sending/receiving push nofications from the Simulator");
#endif
    messageData = [[NSDictionary dictionaryWithObjectsAndKeys:
                    [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:@"New Message!" forKey:@"alert"] forKey:@"aps"], @"push",
                    @"Test Message", @"title",
                    @"This is a message sent from tests", @"message",
                    [tags allObjects], @"tags",
                    nil] retain];
    [[InboxTestPushHandler shared] pushMessageData:messageData delegate:self selector:@selector(receivedSentMessage:)];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&messageReceived processingString:@"Waiting for message to be received..."];
    GHAssertTrue(messageReceived, @"Message not received.  We timed out!  :(");

    // test inbox messages
    messageCount = 2;
    [self createDefaultInbox];
    [[UAInboxMessageList defaultInbox] retrieveMessageList];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&messageListLoaded processingString:@"Waiting for message list to load..."];
    GHAssertTrue(messageListLoaded, @"Message list not loaded.  We timed out!  :(");

    // the first inbox should also received the message.
    [self tearDown];
    [self setUp];
    [[NSUserDefaults standardUserDefaults] setObject:firstMailboxDictionary forKey:[[UAirship shared] appId]];
    messageCount = 2;
    [self createDefaultInbox];
    [[UAInboxMessageList defaultInbox] retrieveMessageList];
    [self spinRunThreadWithTimeOut:10 finishedFlag:&messageListLoaded processingString:@"Waiting for message list to load..."];
    GHAssertTrue(messageListLoaded, @"Message list not loaded.  We timed out!  :(");
}

#pragma mark Test set alias and tags when changed device token

- (void)testUpdateDeviceTokenKeepsAliasAndTags {
    UALOG(@"Test update device token keeps tags and aliases");
    [self createDefaultInbox];

    NSMutableSet *tags = [NSMutableSet setWithObjects:@"a", @"b", nil];
    [UAUser defaultUser].tags = tags;
    [UAUser defaultUser].alias = @"TestAlias";
    [[UAUser defaultUser] updateUserWithDelegate:self finish:nil fail:nil];
    //[[UAInboxMessageList defaultInbox] modifyInboxAlias:@"Test Alias" tags:tags];

    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([UAUser defaultUser].alias == nil && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for tags to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertNotNil([UAUser defaultUser].alias, @"Alias is still nil.  We timed out! :(");

    // Just reverse the mocked string for a new device token to test with
    NSString *newDeviceToken = [self reverseString:[UAirship shared].deviceToken];
    //[UAirship shared].deviceToken = newDeviceToken;
    [[UAirship shared] setDeviceToken:newDeviceToken];
    // Check that this update doesn't wipe out our alias & tags
    [[UAUser defaultUser] updateDefaultDeviceToken];

    giveUpDate = [NSDate dateWithTimeIntervalSinceNow:10];
    while ([UAirship shared].deviceTokenHasChanged == YES && [giveUpDate timeIntervalSinceNow] > 0) {
        UALOG(@"Waiting for tags to be set...");
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }

    GHAssertFalse([UAirship shared].deviceTokenHasChanged, @"[UAirship shared].deviceTokenHasChanged is still YES.  We timed out! :(");
    GHAssertEqualStrings([UAirship shared].deviceToken, newDeviceToken, @"Airship does not have the correct device token after it was changed");

    // Check against data on the server to make sure it got set there as well as on the client

    NSString *url = [NSString stringWithFormat:@"%@/api/user/%@", [UAirship shared].server, [UAUser defaultUser].username];
    UA_ASIHTTPRequest *userReq = [UA_ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
    userReq.username = [UAirship shared].appId;
    userReq.password = [UAirship shared].appSecret;

    [userReq startSynchronous];

    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSDictionary* jsonResponse = [parser objectWithString: [userReq responseString]];
    UALOG(@"Response status code/desc = %d %@", userReq.responseStatusCode, userReq.responseStatusMessage);
    UALOG(@"Response string: %@", [userReq responseString]);
    [parser release];

    NSArray *tagsArray = [jsonResponse objectForKey:@"tags"];
    GHAssertNotNil(tagsArray, @"Tags are nil on server");
    GHAssertEqualObjects([NSSet setWithArray:tagsArray], tags, @"Tags returned from server is not correct");
    NSString *alias = [jsonResponse objectForKey:@"alias"];
    GHAssertNotNil(alias, @"Alias is nil on the server. :(");
    GHAssertEqualStrings(alias, @"Test Alias", @"Alias is incorrect on the server.");
}

@end
