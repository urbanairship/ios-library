/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAUtils+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAPush+Internal.h"
#import "UASchedule+Internal.h"
@interface UAInAppRemoteDataClientTest : UABaseTest
@property (nonatomic,strong) UAInAppRemoteDataClient *remoteDataClient;
@property (nonatomic, strong) UARemoteDataPublishBlock publishBlock;
@property (nonatomic, strong) id mockRemoteDataManager;
@property (nonatomic, strong) id mockScheduler;
@property (nonatomic, strong) id mockPush;
@end

@implementation UAInAppRemoteDataClientTest

- (void)setUp {
    [super setUp];
    
    uaLogLevel = UALogLevelDebug;
    
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
    
    self.mockPush = [self mockForClass:[UAPush class]];
    [[[self.mockPush expect] andReturn:nil] channelID];

    self.mockScheduler = [self mockForClass:[UAInAppMessageManager class]];
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        completionHandler(@[]);
    }] getSchedulesWithMessageID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self.mockScheduler remoteDataManager:self.mockRemoteDataManager dataStore:self.dataStore push:self.mockPush];
    XCTAssertNotNil(self.remoteDataClient);
    
    // verify setup
    XCTAssertNotNil(self.remoteDataClient);
    XCTAssertNotNil(self.publishBlock);
    [self.mockPush verify];
    [self.mockRemoteDataManager verify];
}

- (void)testMissingInAppMessageRemoteData {
    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be scheduled");
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithID:OCMOCK_ANY];
    
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
    }] cancelMessagesWithID:OCMOCK_ANY];
    
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
                                                    @"body" : @{
                                                            @"text" : @"hi there"
                                                            },
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

        NSMutableArray *schedules = [NSMutableArray array];
        for (UAInAppMessageScheduleInfo *info in schedules) {
            [schedules addObject:[UASchedule scheduleWithIdentifier:info.message.identifier info:info]];
        }
        completionHandler(schedules);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];
    
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
                                                    @"body" : @{
                                                            @"text" : @"hi there"
                                                            },
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
        
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAInAppMessageScheduleInfo *info in schedules) {
            [schedules addObject:[UASchedule scheduleWithIdentifier:info.message.identifier info:info]];
        }
        completionHandler(schedules);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        XCTFail(@"No messages should be cancelled");
    }] cancelMessagesWithID:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

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
                                                    @"body" : @{
                                                            @"text" : @"hi there"
                                                            },
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
        
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAInAppMessageScheduleInfo *info in scheduleInfo) {
            [schedules addObject:[UASchedule scheduleWithIdentifier:info.message.identifier info:info]];
        }
        completionHandler(schedules);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(callsToScheduleMessages,1);
    
    // setup to send same message again
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

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
                                                    @"body" : @{
                                                            @"text" : @"hi there"
                                                            },
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
                                                    @"body" : @{
                                                            @"text" : @"hi there"
                                                            },
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
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    __block NSUInteger scheduledMessages = 0;
    __block NSUInteger cancelledMessages = 0;

    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;

        scheduledMessages += scheduleInfo.count;

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        
        NSMutableArray *schedules = [NSMutableArray array];
        for (UAInAppMessageScheduleInfo *info in scheduleInfo) {
            [schedules addObject:[UASchedule scheduleWithIdentifier:info.message.identifier info:info]];
        }
        completionHandler(schedules);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        cancelledMessages += 1;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(nil);
    }] editScheduleWithID:OCMOCK_ANY edits:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);

    // setup to delete one message
    scheduledMessages = 0;
    cancelledMessages = 0;

    inAppMessages = @[message2];
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(scheduledMessages, 0);
    XCTAssertEqual(cancelledMessages, 1);
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
                                               @"body" : @{
                                                       @"text" : @"hi there"
                                                       },
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
                                               @"body" : @{
                                                       @"text" : @"hi there"
                                                       },
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
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}];
    
    __block NSUInteger scheduledMessages = 0;
    __block NSUInteger cancelledMessages = 0;

    // expectations
    [[[self.mockScheduler expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UAInAppMessageScheduleInfo *> *scheduleInfo = (__bridge NSArray<UAInAppMessageScheduleInfo *> *)arg;

        scheduledMessages += scheduleInfo.count;

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        NSMutableArray *schedules = [NSMutableArray array];
        for (UAInAppMessageScheduleInfo *info in scheduleInfo) {
            [schedules addObject:[UASchedule scheduleWithIdentifier:info.message.identifier info:info]];
        }
        completionHandler(schedules);
    }] scheduleMessagesWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockScheduler stub] andDo:^(NSInvocation *invocation) {
        cancelledMessages += 1;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(nil);
    }] editScheduleWithID:OCMOCK_ANY edits:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);
    
    // setup empty payload
    UARemoteDataPayload *emptyInAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                       timestamp:[NSDate date]
                                                                                            data:@{}];
    
    // test
    self.publishBlock(@[emptyInAppRemoteDataPayload]);
    [self.remoteDataClient.operationQueue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockScheduler verify];
    XCTAssertEqual(cancelledMessages, 2);
}

- (void)testNewUserCutoffTime {
    // verify
    NSDate *scheduleNewUserCutoffTime = [self.remoteDataClient.scheduleNewUserCutOffTime copy];
    XCTAssertEqualWithAccuracy([scheduleNewUserCutoffTime timeIntervalSinceNow], 0, 1, @"after first init, schedule new user cut off time should be approximately now");

    // setup
    self.remoteDataClient = nil;
    
    // test
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self.mockScheduler remoteDataManager:self.mockRemoteDataManager dataStore:self.dataStore push:self.mockPush];
    XCTAssertNotNil(self.remoteDataClient);

    // verify
    XCTAssertEqualObjects(self.remoteDataClient.scheduleNewUserCutOffTime, scheduleNewUserCutoffTime, @"after second init, schedule new user cut off time should stay the same.");
}

- (void)testExistingUserCutoffTime {
    // start with empty data store (new app install)
    [self.dataStore removeAll];

    // an existing user already has a channelID
    self.mockPush = [self mockForClass:[UAPush class]];
    [[[self.mockPush expect] andReturn:@"sample-channel-id"] channelID];
    
    // test
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithScheduler:self.mockScheduler remoteDataManager:self.mockRemoteDataManager dataStore:self.dataStore push:self.mockPush];
    XCTAssertNotNil(self.remoteDataClient);

    // verify
    XCTAssertEqualObjects(self.remoteDataClient.scheduleNewUserCutOffTime, [NSDate distantPast], @"existing users should get a cut-off time in the distant past");
}

@end
