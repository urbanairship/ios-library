/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAInboxStore+Internal.h"
#import "UAUtils.h"

static UAUser *mockUser_ = nil;

@protocol UAInboxMessageListMockNotificationObserver
- (void)messageListWillUpdate;
- (void)messageListUpdated;
@end

@interface UAInboxMessageListTest : UABaseTest
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
    self.mockUser = [self mockForClass:[UAUser class]];
    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_userCreated];
    }] isCreated];

    self.mockInboxAPIClient = [self mockForClass:[UAInboxAPIClient class]];

    self.mockMessageListNotificationObserver = [self mockForProtocol:@protocol(UAInboxMessageListMockNotificationObserver)];

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
        failureBlock();
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

    XCTestExpectation *messageListWillUpdateExpectation = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdatedExpectation = [self expectationWithDescription:@"messageListUpdated notification received"];
    [[[self.mockMessageListNotificationObserver expect] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdateExpectation fulfill];
    }] messageListWillUpdate];
    [[[self.mockMessageListNotificationObserver expect] andDo:^(NSInvocation *invocation) {
        [messageListUpdatedExpectation fulfill];
    }] messageListUpdated];

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
            failureBlock();
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    XCTestExpectation *messageListWillUpdateExpectation = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdatedExpectation = [self expectationWithDescription:@"messageListUpdated notification received"];
    [[[self.mockMessageListNotificationObserver expect] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdateExpectation fulfill];
    }] messageListWillUpdate];
    [[[self.mockMessageListNotificationObserver expect] andDo:^(NSInvocation *invocation) {
        [messageListUpdatedExpectation fulfill];
    }] messageListUpdated];

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
