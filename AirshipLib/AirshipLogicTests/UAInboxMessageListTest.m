
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxMessageListDelegate.h"
#import "UAInboxAPIClient.h"
#import "UAActionArguments+Internal.h"
#import "UATestSynchronizer.h"
#import "UAirship.h"
#import "UAConfig.h"

static UAUser *mockUser = nil;

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
//a mock delegate we'll pass into the appropriate methods for callbacks
@property (nonatomic, strong) id mockMessageListDelegate;

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
    self.mockMessageListDelegate = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListDelegate)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListNotificationObserver setExpectationOrderMatters:YES];
    [self.mockMessageListDelegate setExpectationOrderMatters:YES];

    self.messageList = [UAInboxMessageList messageListWithUser:self.mockUser client:self.mockInboxAPIClient config:[UAConfig config]];

    //inject the API client
    self.messageList.client = self.mockInboxAPIClient;

    //sign up for NSNotificationCenter events with our mock observer
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)tearDown {
    [self.mockUser stopMocking];

    [self.messageList.queue cancelAllOperations];
    [self waitUntilAllOperationsAreFinished];

    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    [self.mockInboxAPIClient stopMocking];
    [self.mockMessageListDelegate stopMocking];
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
    [self waitUntilAllOperationsAreFinished];
}

#pragma mark delegate methods


//if the user is not created, this method should do nothing.
//the UADisposable return value should be nil.
- (void)testRetrieveMessageListWithDelegateDefaultUserNotCreated {
    self.userCreated = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    XCTAssertNil(disposable, @"disposable should be nil");
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the delegate should get a messageListLoadSucceeded callback.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListDelegate expect] messageListLoadSucceeded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the delegate should get a messageListLoadFailed callback.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithDelegateFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListDelegate expect] messageListLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//calling dispose on the returned disposable should cancel delegate callbacks.
- (void)testRetrieveMessageListWithDelegateSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(304, nil, 0);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    [self waitUntilAllOperationsAreFinished];

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//calling dispose on the returned disposable should cancel delegate callbacks.
- (void)testRetrieveMessageListWithDelegateFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    [self waitUntilAllOperationsAreFinished];

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and batchMarkAsReadFinished callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the delegate should get a batchMarkAsReadFinished callback.
//the UADisposable returned should be non-nil.
- (void)testPerformBatchMarkAsReadWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListDelegate expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:[NSIndexSet indexSet] withDelegate:self.mockMessageListDelegate];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}


//if successful, the observer should get messageListWillLoad and batchDeleteFinished callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the delegate should get a batchDeleteFinished callback.
//the UADisposable returned should be non-nil.
- (void)testPerformBatchDeleteWithDelegateSuccess {
    [[self.mockMessageListDelegate expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [self.messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:[NSIndexSet indexSet] withDelegate:self.mockMessageListDelegate];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
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
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been called");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the failureBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertTrue(fail, @"failure block should have been called");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the succcessBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(304, nil, 0);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
    
    [self waitUntilAllOperationsAreFinished];

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the failureBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];



    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and batchMarkAsReadFinished callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the successBlock should be executed
//the UADisposable returned should be non-nil.
- (void)testPerformBatchMarkAsReadWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.messageList
      performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:[NSIndexSet indexSet] withSuccessBlock:^{
          fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been executed");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and batchDeleteFinished callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the successBlock should be executed
//the UADisposable returned should be non-nil.
- (void)testPerformBatchDeleteWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.messageList
                                performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:[NSIndexSet indexSet] withSuccessBlock:^{
                                    fail = NO;
                                } withFailureBlock:^{
                                    fail = YES;
                                }];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been executed");

    [self.mockMessageListDelegate verify];
    [self.mockMessageListNotificationObserver verify];
}


// Helper method to finish any pending operations on the message list.
- (void)waitUntilAllOperationsAreFinished {
    // Wait for the message list to finish
    while (self.messageList.queue.operationCount > 0)  {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }

    UATestSynchronizer *testSynchronizer = [[UATestSynchronizer alloc] init];

    // Dispatch a block on the main queue. This allow us to wait for everything thats
    // on the main queue at this exact moment to finish
    dispatch_async(dispatch_get_main_queue(), ^{
        [testSynchronizer continue];
    });

    // Wait for main queue block to execute
    [testSynchronizer wait];
}

@end
