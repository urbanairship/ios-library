/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAInboxStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UAInboxStore+Internal.h"
#import "UAInboxMessage.h"
#import "UAUserData+Internal.h"
#import "AirshipTests-Swift.h"


static NSString * const UAInboxMessageListRetrieveTask = @"UAInboxMessageList.retrieve";
static NSString * const UAInboxMessageListSyncReadMessagesTask = @"UAInboxMessageList.sync_read_messages";
static NSString * const UAInboxMessageListSyncDeletedMessagesTask = @"UAInboxMessageList.sync_deleted_messages";

@protocol UAInboxMessageListMockNotificationObserver
- (void)messageListWillUpdate;
- (void)messageListUpdated;
@end

@interface UAInboxMessageListTest : UAAirshipBaseTest
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

@property (nonatomic, strong) id mockTaskManager;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);

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

    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAInboxMessageListRetrieveTask, UAInboxMessageListSyncReadMessagesTask, UAInboxMessageListSyncDeletedMessagesTask] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.messageList = [UAInboxMessageList messageListWithUser:self.mockUser
                                                        client:self.mockInboxAPIClient
                                                        config:self.config
                                                    inboxStore:self.testStore
                                            notificationCenter:self.notificationCenter
                                                    dispatcher:[[UATestDispatcher alloc] init]
                                                          date:self.testDate
                                                   taskManager:self.mockTaskManager];

    self.messageList.enabled = YES;

    //inject the API client
    self.messageList.client = self.mockInboxAPIClient;

    //sign up for NSNotificationCenter events with our mock observer
    [self.notificationCenter addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [self.notificationCenter addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)tearDown {
    [self.testStore shutDown];

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

    [[[self.mockInboxAPIClient stub] andReturn:nil] retrieveMessageList:[OCMArg anyObjectRef]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    UAInboxMessageListCallbackBlock successBlock = ^{
        [requestSucceeded fulfill];
    };

    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        [self launchRetrieveTaskWithSuccess:successBlock failure:nil];
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:successBlock withFailureBlock:^{}];

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
        __strong NSError **arg;
        [invocation getArgument:&arg atIndex:2];
        *arg = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
    }] retrieveMessageList:[OCMArg anyObjectRef]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    UAInboxMessageListCallbackBlock failureBlock = ^{
        [requestFailed fulfill];
    };

    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        [self launchRetrieveTaskWithSuccess:nil failure:failureBlock];
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{} withFailureBlock:failureBlock];
    [self waitForTestExpectations:@[messageListWillUpdate, requestFailed, messageListUpdated] enforceOrder:YES];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
}

/**
 * Test failed fetch will still refresh the message list by
 * filtering out any expired messages.
 */
- (void)testFilterMessagesOnRefresh {
    self.testDate.dateOverride = [NSDate dateWithTimeIntervalSince1970:0];
    NSDate *expiry = [NSDate dateWithTimeInterval:1 sinceDate:self.testDate.dateOverride];

    [self.testStore syncMessagesWithResponse:@[[self createMessageDictionaryWithMessageID:@"messageID" expiry:expiry]]];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        __strong NSError **arg;
        [invocation getArgument:&arg atIndex:2];
        *arg = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
    }] retrieveMessageList:[OCMArg anyObjectRef]];

    // Refresh the listing to pick up the inbox store change
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"updated message list"];

    UAInboxMessageListCallbackBlock failureBlock = ^{
        [testExpectation fulfill];
    };

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRetrieveTaskWithSuccess:nil failure:failureBlock];
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:failureBlock];

    [self waitForTestExpectations];

    XCTAssertEqual(1, self.messageList.messages.count);
    XCTAssertEqual(@"messageID", self.messageList.messages[0].messageID);

    // Move the data past the expiry
    self.testDate.dateOverride = [NSDate dateWithTimeInterval:1 sinceDate:expiry];

    // Refresh the message again
    testExpectation = [self expectationWithDescription:@"request finished"];

    failureBlock = ^{
        [testExpectation fulfill];
    };

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRetrieveTaskWithSuccess:nil failure:failureBlock];
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:failureBlock];

    [self waitForTestExpectations];

    // Verify the message was filtered out
    XCTAssertEqual(0, self.messageList.messages.count);
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the succcessBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andReturn:nil] retrieveMessageList:[OCMArg anyObjectRef]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        // Delay launching to give the disposable time to work
        dispatch_async(dispatch_get_main_queue(), ^{
            [self launchRetrieveTaskWithSuccess:nil failure:nil];
        });
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

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
    XCTestExpectation *messageListWillUpdate = [self expectationWithDescription:@"messageListWillUpdate notification received"];
    XCTestExpectation *messageListUpdated = [self expectationWithDescription:@"messageListUpdated notification received"];

    [[[self.mockInboxAPIClient stub] andDo:^(NSInvocation *invocation) {
        __strong NSError **arg;
        [invocation getArgument:&arg atIndex:2];
        *arg = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
    }] retrieveMessageList:[OCMArg anyObjectRef]];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListWillUpdate fulfill];
    }] messageListWillUpdate];

    [[[self.mockMessageListNotificationObserver stub] andDo:^(NSInvocation *invocation) {
        [messageListUpdated fulfill];
    }] messageListUpdated];

    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        // Delay launching to give the disposable time to work
        dispatch_async(dispatch_get_main_queue(), ^{
            [self launchRetrieveTaskWithSuccess:nil failure:nil];
        });
    }] enqueueRequestWithID:UAInboxMessageListRetrieveTask options:OCMOCK_ANY];

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

- (void)launchRetrieveTaskWithSuccess:(UAInboxMessageListCallbackBlock)successBlock failure:(UAInboxMessageListCallbackBlock)failureBlock {
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    void(^callback)(BOOL) = ^(BOOL success) {
        if (success && successBlock) {
            successBlock();
        } else if (!success && failureBlock) {
            failureBlock();
        }

        [self.notificationCenter postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
    };

    [[[mockTask stub] andReturn:UAInboxMessageListRetrieveTask] taskID];
    [[[mockTask stub] andReturn:[[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                requiresNetwork:NO
                         extras:@{@"retrieveCallback" : callback}]] requestOptions];
    self.launchHandler(mockTask);
}

@end

