
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxMessageListDelegate.h"
#import "UAInboxAPIClient.h"
#import "UAUser+Test.h"

static UAUser *mockUser = nil;

@protocol UAInboxMessageListMockNotificationObserver
- (void)messageListWillUpdate;
- (void)messageListUpdated;
@end

@interface UAInboxMessageListTest : XCTestCase
//the mock inbox API client we'll inject into the message list
@property(nonatomic, strong) id mockInboxAPIClient;
//a mock (old-school) message list observer that will receive deprecated callbacks
@property(nonatomic, strong) id mockMessageListObserver;
//a mock object that will sign up for NSNotificationCenter events
@property(nonatomic, strong) id mockMessageListNotificationObserver;
//a mock delegate we'll pass into the appropriate methods for callbacks
@property(nonatomic, strong) id mockMessageListDelegate;
@end

@implementation UAInboxMessageListTest

- (void)setUp {
    [super setUp];

    self.mockInboxAPIClient = [OCMockObject mockForClass:[UAInboxAPIClient class]];
    self.mockMessageListObserver = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListObserver)];

    self.mockMessageListNotificationObserver = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListMockNotificationObserver)];
    self.mockMessageListDelegate = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListDelegate)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListObserver setExpectationOrderMatters:YES];
    [self.mockMessageListNotificationObserver setExpectationOrderMatters:YES];
    [self.mockMessageListDelegate setExpectationOrderMatters:YES];

    //inject the API client
    [UAInbox shared].messageList.client = self.mockInboxAPIClient;

    //add our (deprecated) message list observer
    [[UAInbox shared].messageList addObserver:self.mockMessageListObserver];

    //sign up for NSNotificationCenter events with our mock observer
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];

    //swizzle the defaultUserCreated method to always return YES
    [UAUser swizzleDefaultUserCreated];
}

- (void)tearDown {
    //unswizzle the defaultUserCreated back to its normal implementation
    [UAUser unswizzleDefaultUserCreated];

    //undo observer sign-ups
    [[UAInbox shared].messageList removeObservers];

    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    [super tearDown];
}

- (void)testRetrieveMessageListDefaultUserNotCreated {
    //if there's no user, retrieveMessageList should do nothing
    [UAUser unswizzleDefaultUserCreated];
    [[UAInbox shared].messageList retrieveMessageList];
    [UAUser swizzleDefaultUserCreated];
}

- (void)testRetrieveMessageListSuccess {

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientRetrievalSuccessBlock successBlock = (__bridge UAInboxClientRetrievalSuccessBlock) arg;
        successBlock(nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] messageListLoaded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList retrieveMessageList];
}

- (void)testRetrieveMessageListFailure {

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] inboxLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList retrieveMessageList];
}

- (void)testRetrieveMessageListWithDelegateDefaultUserNotCreated {
    //if there's no user, the delegate version of this method should do nothing and return a nil disposable
    [UAUser unswizzleDefaultUserCreated];

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    XCTAssertNil(disposable, @"disposable should be nil");

    [UAUser swizzleDefaultUserCreated];
}

- (void)testRetrieveMessageListWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientRetrievalSuccessBlock successBlock = (__bridge UAInboxClientRetrievalSuccessBlock) arg;
        successBlock(nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] messageListLoaded];

    [[self.mockMessageListDelegate expect] messageListLoadSucceeded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testRetrieveMessageListWithDelegateFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] inboxLoadFailed];

    [[self.mockMessageListDelegate expect] messageListLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testRetrieveMessageListWithDelegateSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientRetrievalSuccessBlock successBlock = (__bridge UAInboxClientRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(nil, 0);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] messageListLoaded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
}

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

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] inboxLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks

    trigger();
}

- (void)testRetrieveMessageListWithBlocksDefaultUserNotCreated {
    //if there's no user, the block version of this method should do nothing and return a nil disposable
    [UAUser unswizzleDefaultUserCreated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNil(disposable, @"disposable should be nil");
    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [UAUser swizzleDefaultUserCreated];
}

- (void)testRetrieveMessageListWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientRetrievalSuccessBlock successBlock = (__bridge UAInboxClientRetrievalSuccessBlock) arg;
        successBlock(nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] messageListLoaded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been called");
}

- (void)testRetrieveMessageListWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] inboxLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertTrue(fail, @"failure block should have been called");
}

- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientRetrievalSuccessBlock successBlock = (__bridge UAInboxClientRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(nil, 0);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] messageListLoaded];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have been executed");
}

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

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] inboxLoadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have been executed");
}

- (void)testPerformBatchMarkAsReadSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil];
}

- (void)testPerformBatchMarkAsReadFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil];
}

- (void)testPerformBatchMarkAsReadWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFinished];

    [[self.mockMessageListDelegate expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testPerformBatchMarkAsReadWithDelegateFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFailed];

    [[self.mockMessageListDelegate expect] batchMarkAsReadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testPerformBatchMarkAsReadWithDelegateSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        trigger = ^{
            successBlock();
        };
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
}

- (void)testPerformBatchMarkAsReadWithDelegateFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFailed];

    [[self.mockMessageListDelegate expect] batchMarkAsReadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
}

- (void)testPerformBatchMarkAsReadWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [[UAInbox shared].messageList
      performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withSuccessBlock:^{
          fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been executed");
}

- (void)testPerformBatchMarkAsReadWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = NO;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"failure block should have been executed");
}

- (void)testPerformBatchMarkAsReadWithBlocksSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        trigger = ^{
            successBlock();
        };
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList
                                performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withSuccessBlock:^{
                                    fail = YES;
                                } withFailureBlock:^{
                                    fail = YES;
                                }];
    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have executed");
}

- (void)testPerformBatchMarkAsReadWithBlocksFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] performBatchMarkAsReadForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchMarkAsReadFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:nil withSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have executed");
}

- (void)testPerformBatchDeleteSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil];
}

- (void)testPerformBatchDeleteFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil];
}

- (void)testPerformBatchDeleteWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFinished];

    [[self.mockMessageListDelegate expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testPerformBatchDeleteWithDelegateFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFailed];

    [[self.mockMessageListDelegate expect] batchDeleteFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

- (void)testPerformBatchDeleteWithDelegateSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        trigger = ^{
            successBlock();
        };
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
}

- (void)testPerformBatchDeleteWithDelegateFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFailed];

    [[self.mockMessageListDelegate expect] batchDeleteFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withDelegate:self.mockMessageListDelegate];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
}

- (void)testPerformBatchDeleteWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [[UAInbox shared].messageList
                                performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withSuccessBlock:^{
                                    fail = NO;
                                } withFailureBlock:^{
                                    fail = YES;
                                }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been executed");
}

- (void)testPerformBatchDeleteWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = NO;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"failure block should have been executed");
}

- (void)testPerformBatchDeleteWithBlocksSuccessDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        trigger = ^{
            successBlock();
        };
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFinished];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList
                                performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withSuccessBlock:^{
                                    fail = YES;
                                } withFailureBlock:^{
                                    fail = YES;
                                }];
    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have executed");
}

- (void)testPerformBatchDeleteWithBlocksFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] performBatchDeleteForMessages:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] messageListWillLoad];
    [[self.mockMessageListObserver expect] batchDeleteFailed];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:nil withSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];
    
    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();
    
    XCTAssertFalse(fail, @"callback blocks should not have executed");
}

@end
