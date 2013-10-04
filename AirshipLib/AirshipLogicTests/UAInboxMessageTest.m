
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInboxMessage.h"
#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxDBManager.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxMessageListDelegate.h"
#import "UAInboxAPIClient.h"

@interface UAInboxMessageTest : XCTestCase

@property(nonatomic, strong) UAInboxDBManager *dbManager;
@property(nonatomic, strong) UAInboxMessage *message;
//the mock inbox API client we'll inject into the message
@property(nonatomic, strong) id mockInboxAPIClient;
//a mock (old-school) message list observer that will receive deprecated callbacks
@property(nonatomic, strong) id mockMessageListObserver;
//a mock delegate we'll pass into the appropriate methods for callbacks
@property(nonatomic, strong) id mockMessageListDelegate;

@end

@implementation UAInboxMessageTest

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

- (void)setUp {
    [super setUp];
    self.dbManager = [UAInboxDBManager shared];
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"12345"]];
    self.message = [[self.dbManager getMessages] objectAtIndex:0];

    self.message.unread = YES;
    //this is normally set when a message is associated with the message list, needed for
    //sending (deprecated) UAInboxMessageListObserver callbacks
    self.message.inbox = [UAInbox shared].messageList;

    self.mockInboxAPIClient = [OCMockObject mockForClass:[UAInboxAPIClient class]];
    self.mockMessageListObserver = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListObserver)];

    self.mockMessageListDelegate = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListDelegate)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListObserver setExpectationOrderMatters:YES];
    [self.mockMessageListDelegate setExpectationOrderMatters:YES];

    //inject the API client
    self.message.client = self.mockInboxAPIClient;

    //add our (deprecated) message list observer
    [[UAInbox shared].messageList addObserver:self.mockMessageListObserver];
}

- (void)tearDown {
    // Put teardown code here; it will be run once, after the last test case.
    //undo observer sign-ups
    [self.mockInboxAPIClient stopMocking];
    [self.mockMessageListObserver stopMocking];
    [self.mockMessageListDelegate stopMocking];
    [self.dbManager deleteMessages:[self.dbManager getMessages]];
    [[UAInbox shared].messageList removeObservers];
    [super tearDown];
}

#pragma mark deprecated methods

//if successful, the observer should get a singleMessageMarkAsReadFinished callback
- (void)testMarkAsReadSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFinished:[OCMArg any]];
    
    [self.message markAsRead];

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if unsuccessful, the observer should get a singleMessageMarkAsReadFailed callback
- (void)testMarkAsReadFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFailed:[OCMArg any]];

    [self.message markAsRead];

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if the inbox is currently batch updating, this method should do nothing
- (void)testMarkAsReadBatchUpdating {
    [UAInbox shared].messageList.isBatchUpdating = YES;
    [self.message markAsRead];
    //if the inbox is batch updating, this should be a no-op. otherwise,
    //unexpected methods will be called.
    [UAInbox shared].messageList.isBatchUpdating = NO;
}

//if the message is already marked read, this method should do nothing
- (void)testMarkAsReadAlreadyMarkedRead {
    self.message.unread = NO;
    [self.message markAsRead];
    //if the message is already marked read, this should be a no-op. otherwise,
    //unexpected methods will be called.
    self.message.unread = YES;
}

#pragma mark delegate methods

//if successful, the observer should get a singleMessageMarkAsReadFinished callback.
//the delegate should get a singleMessageMarkAsReadFinished callback.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithDelegateSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFinished:[OCMArg any]];
    [[self.mockMessageListDelegate expect] singleMessageMarkAsReadFinished:[OCMArg any]];

    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if unsuccessful, the observer should get a singleMessageMarkAsReadFailed callback.
//the delegate should get a singleMessageMarkAsReadFailed callback.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithDelegateFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFailed:[OCMArg any]];
    [[self.mockMessageListDelegate expect] singleMessageMarkAsReadFailed:[OCMArg any]];

    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if successful, the observer should get a singleMessageMarkAsReadFinished callback.
//if dispose is called on the disposable, delegate callbacks should be cancelled.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithDelegateSuccessDisposal {

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
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFinished:[OCMArg any]];

    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];
    trigger();

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if unsuccessful, the observer should get a singleMessageMarkAsReadFailed callback.
//if dispose is called on the disposable, delegate callbacks should be cancelled.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithDelegateFailureDisposal {

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
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFailed:[OCMArg any]];

    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    [disposable dispose];
    trigger();

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if the inbox is currently batch updating, this method should do nothing.
//the returned disposable should be nil.
- (void)testMarkAsReadWithDelegateBatchUpdating {
    [UAInbox shared].messageList.isBatchUpdating = YES;
    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    XCTAssertNil(disposable, @"disposable should be nil");
    //if the inbox is batch updating, this should be a no-op. otherwise,
    //unexpected methods will be called.
    [UAInbox shared].messageList.isBatchUpdating = NO;
}

//if the message is already marked as read, this method should do nothing.
//the returned disposable should be nil.
- (void)testMarkAsReadWithDelegateAlreadyMarkedRead {
    self.message.unread = NO;
    UADisposable *disposable = [self.message markAsReadWithDelegate:self.mockMessageListDelegate];
    XCTAssertNil(disposable, @"disposable should be nil");
    //if the message is already marked read, this should be a no-op. otherwise,
    //unexpected methods will be called.
    self.message.unread = YES;
}

#pragma mark block-based methods

//if successful, the observer should get a singleMessageMarkAsReadFinished callback.
//the successBlock should be executed.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientSuccessBlock successBlock = (__bridge UAInboxClientSuccessBlock) arg;
        successBlock();
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFinished:[OCMArg any]];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = NO;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"failure callback should have been executed");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if successful, the observer should get a singleMessageMarkAsReadFailed callback.
//the failureBlock should be executed.
//the returned disposable should be non-nil.
- (void)testMarkAsReadWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFailed:[OCMArg any]];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = YES;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = NO;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"failure callback should have been executed");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if successful, the observer should get a singleMessageMarkAsReadFinished callback.
//if dispose is called on the disposable, the successBlock should not be executed.
- (void)testMarkAsReadWithBlocksSuccessDisposal {

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
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFinished:[OCMArg any]];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = YES;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [disposable dispose];
    trigger();

    XCTAssertFalse(fail, @"callbacks should not have executed");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if successful, the observer should get a singleMessageMarkAsReadFailed callback.
//if dispose is called on the disposable, the failureBlock should not be executed.
- (void)testMarkAsReadWithBlocksFailureDisposal {

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
    }] markMessageRead:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListObserver expect] singleMessageMarkAsReadFailed:[OCMArg any]];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = YES;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = YES;
    }];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");

    [disposable dispose];
    trigger();

    XCTAssertFalse(fail, @"callbacks should not have executed");

    [self.mockMessageListObserver verify];
    [self.mockMessageListDelegate verify];
}

//if the inbox is currently batch updating, this method should do nothing.
//the returned disposable should be nil.
- (void)testMarkAsReadWithBlocksBatchUpdating {
    [UAInbox shared].messageList.isBatchUpdating = YES;
    __block BOOL fail = NO;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = YES;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = YES;
    }];

    XCTAssertNil(disposable, @"disposable should be nil");
    XCTAssertFalse(fail, @"callbacks should not have executed");
    //if the inbox is batch updating, this should be a no-op. otherwise,
    //unexpected methods will be called.
    [UAInbox shared].messageList.isBatchUpdating = NO;
}

//if the message is already marked as read, this method should do nothing.
//the returned disposable should be nil.
- (void)testMarkAsReadWithBlocksAlreadyMarkedRead {
    self.message.unread = NO;
    __block BOOL fail = NO;

    UADisposable *disposable = [self.message markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        fail = YES;
    } withFailureBlock:^(UAInboxMessage *message){
        fail = YES;
    }];

    XCTAssertNil(disposable, @"disposable should be nil");
    XCTAssertFalse(fail, @"callbacks should not have executed");
    //if the message is already marked read, this should be a no-op. otherwise,
    //unexpected methods will be called.
    self.message.unread = YES;
}

@end
