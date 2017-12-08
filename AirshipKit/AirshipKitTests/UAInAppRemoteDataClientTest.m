/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAUtils.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageManager.h"

@interface UAInAppRemoteDataClientTest : UABaseTest
@property (nonatomic,strong) UAInAppRemoteDataClient *remoteDataClient;
@property (nonatomic, strong) id mockRemoteDataManager;
@property (nonatomic, strong) UARemoteDataPublishBlock publishBlock;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockScheduler;

@end

@implementation UAInAppRemoteDataClientTest

- (void)setUp {
    [super setUp];
    
    // mock remote data
    self.mockRemoteDataManager = [self mockForClass:[UARemoteDataManager class]];
    [[[self.mockRemoteDataManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        
        // verify payload types
        [invocation getArgument:&arg atIndex:2];
        NSArray<NSString *> *types = (__bridge NSArray<NSString *> *)arg;
        XCTAssertTrue(types.count == 1);
        XCTAssertTrue([types containsObject:@"in_app_messages"]);
        
        // verify and check publishBlock
        [invocation getArgument:&arg atIndex:3];
        self.publishBlock = (__bridge UARemoteDataPublishBlock)arg;
        XCTAssertNotNil(self.publishBlock);
    }] subscribeWithTypes:OCMOCK_ANY block:OCMOCK_ANY];
    
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[NSString stringWithFormat:@"UAInAppRemoteDataClientTest.%@",self.name]];
    XCTAssertNotNil(self.dataStore);
    [self.dataStore removeAll]; // start with an empty datastore
    
    self.mockScheduler = [self mockForClass:[UAInAppMessageManager class]];
    
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self.mockScheduler remoteDataManager:self.mockRemoteDataManager dataStore:self.dataStore];
    
    // verify setup
    XCTAssertNotNil(self.remoteDataClient);
    XCTAssertNotNil(self.publishBlock);
    [self.mockRemoteDataManager verify];
}

- (void)tearDown {
    [self.dataStore removeAll];
    
    [super tearDown];
}

- (void)testMissingInAppMessageRemoteData {
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be scheduled");
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithIDs:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,0);
}

- (void)testEmptyInAppMessageList {
    // setup
    NSArray *inAppMessages = @[];
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be scheduled");
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithIDs:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,0);
}

- (void)testNonEmptyInAppMessageList {
    // setup
    NSString *messageID = [NSUUID UUID].UUIDString;
    NSDictionary *simpleMessage = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": messageID,
                                            @"push_id": [NSUUID UUID].UUIDString,
                                            @"display_type": @"banner",
                                            @"display": @{
                                                    },
                                            },
                                    @"created": @"2017-12-04T19:07:54.564",
                                    @"last_updated": @"2017-12-04T19:07:54.564",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                                }
                                            ]
                                    };
    NSArray *inAppMessages = @[simpleMessage];
    NSUInteger expectedNumberOfScheduleInfos = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;
        
        XCTAssertEqual(scheduleInfo.count, expectedNumberOfScheduleInfos);
        
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        completionHandler(@[]);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithIDs:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
}

- (void)testSamePayloadSentTwice {
    // setup
    NSString *messageID = [NSUUID UUID].UUIDString;
    NSDictionary *simpleMessage = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": messageID,
                                            @"push_id": [NSUUID UUID].UUIDString,
                                            @"display_type": @"banner",
                                            @"display": @{
                                                    },
                                            },
                                    @"created": @"2017-12-04T19:07:54.564",
                                    @"last_updated": @"2017-12-04T19:07:54.564",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                                }
                                            ]
                                    };
    NSArray *inAppMessages = @[simpleMessage];
    NSUInteger expectedNumberOfScheduleInfos = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;
        
        XCTAssertEqual(scheduleInfo.count, expectedNumberOfScheduleInfos);
        
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        
        completionHandler(@[]);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithIDs:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
        
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
}

- (void)testSameMessageSentTwice {
    // setup
    NSString *messageID = [NSUUID UUID].UUIDString;
    NSDictionary *simpleMessage = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": messageID,
                                            @"push_id": [NSUUID UUID].UUIDString,
                                            @"display_type": @"banner",
                                            @"display": @{
                                                    },
                                            },
                                    @"created": @"2017-12-04T19:07:54.564",
                                    @"last_updated": @"2017-12-04T19:07:54.564",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                                }
                                            ]
                                    };
    NSArray *inAppMessages = @[simpleMessage];
    NSUInteger expectedNumberOfScheduleInfos = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;
        
        XCTAssertEqual(scheduleInfo.count, expectedNumberOfScheduleInfos);
        
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        
        completionHandler(@[]);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithIDs:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    
    // setup to send same message again
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
   // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
}

- (void)testOneDeletedInAppMessage {
    // setup to add messages
    NSString *message1ID = [NSUUID UUID].UUIDString;
    NSDictionary *message1 = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": message1ID,
                                            @"push_id": [NSUUID UUID].UUIDString,
                                            @"display_type": @"banner",
                                            @"display": @{
                                                    },
                                            },
                                    @"created": @"2017-12-04T19:07:54.564",
                                    @"last_updated": @"2017-12-04T19:07:54.564",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                                }
                                            ]
                                    };
    NSString *message2ID = [NSUUID UUID].UUIDString;
    NSDictionary *message2 = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": message2ID,
                                            @"push_id": [NSUUID UUID].UUIDString,
                                            @"display_type": @"banner",
                                            @"display": @{
                                                    },
                                            },
                                    @"created": @"2017-12-04T19:07:54.564",
                                    @"last_updated": @"2017-12-04T19:07:54.564",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                                }
                                            ]
                                    };
    NSArray *inAppMessages = @[message1,message2];
    NSUInteger expectedNumberOfScheduleInfos = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;
        
        XCTAssertEqual(scheduleInfo.count, expectedNumberOfScheduleInfos);
        
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        
        completionHandler(@[]);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    __block NSUInteger callsToCancelMessages = 0;
    __block NSUInteger expectedNumberOfMessagesToCancel = 0;
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        callsToCancelMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<NSString *> *messageIDs = (__bridge NSArray<NSString *> *)arg;
        
        XCTAssertEqual(messageIDs.count, expectedNumberOfMessagesToCancel);
        XCTAssertEqualObjects(messageIDs[0], message1ID);
    }] cancelMessagesWithIDs:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    XCTAssertEqual(callsToCancelMessages,0);

    // setup to delete one message
    inAppMessages = @[message2];
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    expectedNumberOfScheduleInfos = 0;
    expectedNumberOfMessagesToCancel = 1;

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    XCTAssertEqual(callsToCancelMessages,1);
}

- (void)testEmptyInAppMessageListAfterNonEmptyList {
    // setup to add messages
    NSString *message1ID = [NSUUID UUID].UUIDString;
    NSDictionary *message1 = @{@"message": @{
                                       @"name": @"Simple Message",
                                       @"message_id": message1ID,
                                       @"push_id": [NSUUID UUID].UUIDString,
                                       @"display_type": @"banner",
                                       @"display": @{
                                               },
                                       },
                               @"created": @"2017-12-04T19:07:54.564",
                               @"last_updated": @"2017-12-04T19:07:54.564",
                               @"triggers": @[
                                       @{
                                           @"type":@"app_init",
                                           @"goal":@1
                                           }
                                       ]
                               };
    NSString *message2ID = [NSUUID UUID].UUIDString;
    NSDictionary *message2 = @{@"message": @{
                                       @"name": @"Simple Message",
                                       @"message_id": message2ID,
                                       @"push_id": [NSUUID UUID].UUIDString,
                                       @"display_type": @"banner",
                                       @"display": @{
                                               },
                                       },
                               @"created": @"2017-12-04T19:07:55.564",
                               @"last_updated": @"2017-12-04T19:07:55.564",
                               @"triggers": @[
                                       @{
                                           @"type":@"app_init",
                                           @"goal":@1
                                           }
                                       ]
                               };
    NSArray *inAppMessages = @[message1,message2];
    NSUInteger expectedNumberOfScheduleInfos = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;
        
        XCTAssertEqual(scheduleInfo.count, expectedNumberOfScheduleInfos);
        
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        
        completionHandler(@[]);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    __block NSUInteger callsToCancelMessages = 0;
    __block NSUInteger expectedNumberOfMessagesToCancel = 0;
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        callsToCancelMessages++;
        
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<NSString *> *messageIDs = (__bridge NSArray<NSString *> *)arg;
        
        XCTAssertEqual(messageIDs.count, expectedNumberOfMessagesToCancel);
        XCTAssertEqualObjects(messageIDs[0], message1ID);
    }] cancelMessagesWithIDs:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    XCTAssertEqual(callsToCancelMessages,0);
    
    // setup empty payload
    UARemoteDataPayload *emptyInAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                       timestamp:[NSDate date]
                                                                                            data:@{}];
    
    // expectations
    expectedNumberOfScheduleInfos = 0;
    expectedNumberOfMessagesToCancel = 2;
    
    // test
    self.publishBlock(@[emptyInAppRemoteDataPayload]);
    
    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    XCTAssertEqual(callsToCancelMessages,1);
}


@end
