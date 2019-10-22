/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAInboxStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UAInboxStore+Internal.h"
#import "UATestDispatcher.h"
#import "UATestDate.h"
#import "UAInboxMessage.h"
#import "UAUserData+Internal.h"
#import "UAAutoDisposable.h"

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
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAInboxStore *testStore;
@property (nonatomic, strong) UATestDate *testDate;

@end

@implementation UAInboxMessageListTest

- (void)setUp {
    [super setUp];

    self.userCreated = YES;
    self.mockUser = [self mockForClass:[UAUser class]];
    self.testDate = [[UATestDate alloc] init];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        if (self.userCreated) {
            completionHandler(userData);
        } else {
            completionHandler(nil);
        }
    }] getUserData:OCMOCK_ANY];

    self.testStore = [UAInboxStore storeWithName:@"UAInboxMessageListTest." inMemory:YES];

    self.mockInboxAPIClient = [self mockForClass:[UAInboxAPIClient class]];

    self.mockMessageListNotificationObserver = [self mockForProtocol:@protocol(UAInboxMessageListMockNotificationObserver)];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.messageList = [UAInboxMessageList messageListWithUser:self.mockUser
                                                        client:self.mockInboxAPIClient
                                                        config:self.config
                                                    inboxStore:self.testStore
                                            notificationCenter:self.notificationCenter
                                                    dispatcher:[UATestDispatcher testDispatcher]
                                                          date:self.testDate];

    //inject the API client
    self.messageList.client = self.mockInboxAPIClient;

    //sign up for NSNotificationCenter events with our mock observer
    [self.notificationCenter addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [self.notificationCenter addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)tearDown {
    [self.testStore shutDown];
    [self.testStore waitForIdle];

    [self.notificationCenter removeObserver:self.mockMessageListNotificationObserver];
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

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the succcessBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksSuccess {

    XCTestExpectation *requestSucceeded = [self expectationWithDescription:@"request succeeded"];
    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, @[]);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        [requestSucceeded fulfill];
    } withFailureBlock:^{}];

    [self waitForTestExpectations:@[messageListWillUpdate, requestSucceeded, messageListUpdated] enforceOrder:YES];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the failureBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksFailure {
    XCTestExpectation *requestFailed = [self expectationWithDescription:@"request failed"];
    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock();
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
    } withFailureBlock:^{
        [requestFailed fulfill];
    }];

    [self waitForTestExpectations:@[messageListWillUpdate, requestFailed, messageListUpdated] enforceOrder:YES];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

/**
 * Test failed fetch will still refresh the message list by
 * filtering out any expired messages.
 */
- (void)testFilterMessagesOnRefresh {

    self.testDate.absoluteTime = [NSDate dateWithTimeIntervalSince1970:0];
    NSDate *expiry = [NSDate dateWithTimeInterval:1 sinceDate:self.testDate.absoluteTime];

    XCTestExpectation *inboxSynced = [self expectationWithDescription:@"inboxSynced"];

    [self.testStore syncMessagesWithResponse:@[[self createMessageDictionaryWithMessageID:@"messageID" expiry:expiry]]
                            completionHandler:^(BOOL success) {
                                [inboxSynced fulfill];
                            }];

    [self waitForTestExpectations];

    // Setup a failure response
    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock();
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    // Refresh the listing to pick up the inbox store change
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"updated message list"];
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:^{
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqual(1, self.messageList.messages.count);
    XCTAssertEqual(@"messageID", self.messageList.messages[0].messageID);

    // Move the data past the expiry
    self.testDate.absoluteTime = [NSDate dateWithTimeInterval:1 sinceDate:expiry];

    // Refresh the message again
    testExpectation = [self expectationWithDescription:@"request finished"];
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:^{
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];

    // Verify the message was filtered out
    XCTAssertEqual(0, self.messageList.messages.count);
}

/**
 * Helper method for substituting UAAutoDisposable for UADisposable in test.
 */
- (void)useAutoDisposable {
    id mock = [self mockForClass:[UADisposable class]];

     [[[mock stub] andDo:^(NSInvocation *invocation) {
         void *arg;
         [invocation getArgument:&arg atIndex:2];
         UADisposalBlock disposalBlock = (__bridge UADisposalBlock) arg;
         [invocation setReturnValue:(__bridge void * _Nonnull)([UAAutoDisposable disposableWithBlock:disposalBlock])];
     }] disposableWithBlock:OCMOCK_ANY];
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the succcessBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    [self useAutoDisposable];

    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        XCTFail(@"Callback blocks should not be invoked");
    } withFailureBlock:^{
        XCTFail(@"Callback blocks should not be invoked");
    }];

    [self waitForTestExpectations:@[messageListWillUpdate, messageListUpdated] enforceOrder:YES];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the failureBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksFailureDisposal {
    [self useAutoDisposable];

    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock();
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        XCTFail(@"Callback blocks should not be invoked");
    } withFailureBlock:^{
        XCTFail(@"Callback blocks should not be invoked");
    }];

    [self waitForTestExpectations:@[messageListWillUpdate, messageListUpdated] enforceOrder:YES];
}

- (NSDictionary *)createMessageDictionaryWithMessageID:(NSString *)messageID expiry:(NSDate *)expiry {
    NSMutableDictionary *payload = [[self createMessageDictionaryWithMessageID:messageID] mutableCopy];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";

    NSString *expiryString = [dateFormatter stringFromDate:expiry];
    [payload setValue:expiryString forKey:@"message_expiry"];

    return [payload copy];
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
