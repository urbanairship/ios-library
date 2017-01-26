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

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAInboxDBManager+Internal.h"
#import "UAUtils.h"

static UAUser *mockUser_ = nil;

@protocol UAInboxMessageListMockNotificationObserver
- (void)messageListWillUpdate;
- (void)messageListUpdated;
@end

@interface UAInboxMessageListTest : XCTestCase
@property (nonatomic, strong) id mockUser;
@property (nonatomic, assign) BOOL userCreated;

//the mock inbox API client we'll inject into the message list
@property (nonatomic, strong) id mockInboxAPIClient;
//a mock object that will sign up for NSNotificationCenter events
@property (nonatomic, strong) id mockMessageListNotificationObserver;

@property (nonatomic, strong) UAInboxMessageList *messageList;

@end

@implementation UAInboxMessageListTest

- (void)setUp {
    [super setUp];

    self.userCreated = YES;
    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_userCreated];
    }] isCreated];

    self.mockInboxAPIClient = [OCMockObject niceMockForClass:[UAInboxAPIClient class]];

    self.mockMessageListNotificationObserver = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListMockNotificationObserver)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListNotificationObserver setExpectationOrderMatters:YES];

    self.messageList = [UAInboxMessageList messageListWithUser:self.mockUser client:self.mockInboxAPIClient config:[UAConfig config]];

    //inject the API client
    self.messageList.client = self.mockInboxAPIClient;

    //sign up for NSNotificationCenter events with our mock observer
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)tearDown {
    [self.mockUser stopMocking];

    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    [self.mockInboxAPIClient stopMocking];
    [self.mockMessageListNotificationObserver stopMocking];

    [super tearDown];
}

//if there's no user, retrieveMessageList should do nothing
- (void)testRetrieveMessageListDefaultUserNotCreated {
    self.userCreated = NO;

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        XCTFail(@"No user should no-op");
    } withFailureBlock:^{
        XCTFail(@"No user should no-op");
    }];
}

#pragma mark block-based methods

//if the user is not created, this method should do nothing.
//the UADisposable return value should be nil.
- (void)testRetrieveMessageListWithBlocksDefaultUserNotCreated {
    //if there's no user, the block version of this method should do nothing and return a nil disposable
    self.userCreated = NO;

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNil(disposable, @"disposable should be nil");
    XCTAssertFalse(fail, @"callback blocks should not have been executed");
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the succcessBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksSuccess {

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, @[]);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
        [testExpectation fulfill];
    } withFailureBlock:^{
        fail = YES;
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been called");

    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the failureBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksFailure {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(500);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
        [testExpectation fulfill];
    } withFailureBlock:^{
        fail = YES;
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertTrue(fail, @"failure block should have been called");

    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the succcessBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(304, nil);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
        [testExpectation fulfill];
    } withFailureBlock:^{
        fail = YES;
        [testExpectation fulfill];
    }];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    if (!fail) {
        [testExpectation fulfill];
    }

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListNotificationObserver verify];
}


/**
 * Tests the mark as read performance for marking 200 messages as read.
 */
- (void)testMarkMessagesReadPerformance {
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    for (int i = 0; i < 200; i++) {
        [self.messageList.inboxDBManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:[NSUUID UUID].UUIDString]
                                                          context:self.messageList.inboxDBManager.mainContext];
    }

    [self.messageList loadSavedMessages];

    [self measureBlock:^{
        [self.messageList markMessagesRead:self.messageList.messages completionHandler:nil];
    }];
}


/**
 * Tests the mark as read performance for marking 200 messages as deleted.
 */
- (void)testMarkMessagesDeletedPerformance {
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    for (int i = 0; i < 200; i++) {
        [self.messageList.inboxDBManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:[NSUUID UUID].UUIDString]
                                                          context:self.messageList.inboxDBManager.mainContext];
    }

    [self.messageList loadSavedMessages];

    [self measureBlock:^{
        [self.messageList markMessagesDeleted:self.messageList.messages completionHandler:nil];
    }];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the failureBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksFailureDisposal {

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(500);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
        [testExpectation fulfill];
    } withFailureBlock:^{
        fail = YES;
        [testExpectation fulfill];
    }];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    if (!fail) {
        [testExpectation fulfill];
    }

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error){
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListNotificationObserver verify];
}

- (NSDictionary *)createMessageDictionaryWithMessageID:(NSString *)messageID {
    return @{@"message_id": messageID,
             @"title": @"someTitle",
             @"content_type": @"someContentType",
             @"extra": @{@"someKey":@"someValue"},
             @"message_body_url": @"http://someMessageBodyUrl",
             @"message_url": @"http://someMessageUrl",
             @"unread": @"0",
             @"message_sent": @"2013-08-13 00:16:22" };

}

@end
