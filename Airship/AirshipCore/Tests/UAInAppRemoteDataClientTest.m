/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAirship+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAUtils+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageManager.h"
#import "UAPush+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAInAppMessage+Internal.h"
#import "UAActionSchedule.h"
#import "UAINappMessageSchedule.h"

NSString * const UAInAppMessagesScheduledMessagesKey = @"UAInAppRemoteDataClient.ScheduledMessages";

@interface UAInAppRemoteDataClientTest : UAAirshipBaseTest
@property (nonatomic,strong) UAInAppRemoteDataClient *remoteDataClient;
@property (nonatomic, strong) UARemoteDataPublishBlock publishBlock;
@property (nonatomic, strong) NSOperationQueue *queue;

@property (nonatomic, strong) id mockRemoteDataProvider;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockChannel;

@property (nonatomic, strong) NSMutableArray<UASchedule *> *allSchedules;
@end

@implementation UAInAppRemoteDataClientTest

- (void)setUp {
    [super setUp];

    // mock remote data
    self.mockRemoteDataProvider = [self mockForProtocol:@protocol(UARemoteDataProvider)];
    [[[self.mockRemoteDataProvider stub] andDo:^(NSInvocation *invocation) {
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

    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andReturn:nil] identifier];

    self.mockDelegate = [self mockForProtocol:@protocol(UAInAppRemoteDataClientDelegate)];

    self.allSchedules = [NSMutableArray array];
    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;
        completionHandler(self.allSchedules);
    }] getSchedules:OCMOCK_ANY];


    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 1;

    self.remoteDataClient = [UAInAppRemoteDataClient clientWithRemoteDataProvider:self.mockRemoteDataProvider
                                                                    dataStore:self.dataStore
                                                                      channel:self.mockChannel
                                                                   operationQueue:self.queue];
    self.remoteDataClient.delegate = self.mockDelegate;

    [self.remoteDataClient subscribe];
    XCTAssertNotNil(self.publishBlock);
}

- (void)testMetadataChange {
    NSDictionary *metadataA = @{@"cool":@"story"};
    NSDictionary *metadataB = @{@"millennial":@"potato"};

    NSDictionary *expectedSceduleMetadataA = @{@"com.urbanairship.iaa.REMOTE_DATA_METADATA": metadataA};
    NSDictionary *expectedSceduleMetadataB = @{@"com.urbanairship.iaa.REMOTE_DATA_METADATA": metadataB};

    // setup
    NSString *messageID = [NSUUID UUID].UUIDString;
    NSDictionary *simpleMessage = @{@"message": @{
                                            @"name": @"Simple Message",
                                            @"message_id": messageID,
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
    NSUInteger expectedNumberOfSchedules = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   metadata:metadataA];

    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        for (UASchedule *schedule in schedules) {
            XCTAssertEqualObjects(expectedSceduleMetadataA, schedule.metadata);
        }

        XCTAssertEqual(schedules.count, expectedNumberOfSchedules);

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        [self.allSchedules addObjectsFromArray:schedules];
        completionHandler(YES);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages, 1);

    XCTestExpectation *editCalled = [self expectationWithDescription:@"Edit call should be made for metadata change"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(self.allSchedules[0]);
        [editCalled fulfill];
    }] editScheduleWithID:self.allSchedules[0].identifier edits:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAScheduleEdits *edits = obj;
        return [edits.metadata isEqualToDictionary:expectedSceduleMetadataB];
    }] completionHandler:OCMOCK_ANY];

    // setup to same message with metadata B
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              metadata:metadataB];
    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    [self waitForTestExpectations];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages,1);
}


- (void)testMissingInAppMessageRemoteData {
    [[self.mockDelegate reject] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.publishBlock(@[]);
    [self.queue waitUntilAllOperationsAreFinished];
}


- (void)testEmptyInAppMessageList {
    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[]}
                                                                                   metadata:@{@"cool" : @"story"}];

    [[self.mockDelegate reject] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];
}


- (void)testNonEmptyInAppMessageList {
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

    UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[simpleMessage]}
                                                                                   metadata:@{@"cool" : @"story"}];


    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        XCTAssertEqual(schedules.count, 1);

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        [self.allSchedules addObjectsFromArray:schedules];
        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages, 1);
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
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   metadata:@{@"cool" : @"story"}];

    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        XCTAssertEqual(schedules.count, expectedNumberOfScheduleInfos);

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        [self.allSchedules addObjectsFromArray:schedules];
        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages,1);

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    // verify
    [self.mockDelegate verify];
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
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   metadata:@{@"cool" : @"story"}];

    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        XCTAssertEqual(schedules.count, expectedNumberOfScheduleInfos);

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        [self.allSchedules addObjectsFromArray:schedules];

        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages,1);

    // setup to send same message again
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              metadata:@{@"cool" : @"story"}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
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

    __block UARemoteDataPayload *inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                          timestamp:[NSDate date]
                                                                                               data:@{@"in_app_messages":inAppMessages}
                                                                                           metadata:@{@"cool" : @"story"}];
    __block NSUInteger scheduledMessages = 0;
    __block NSUInteger cancelledMessages = 0;
    __block NSUInteger editedMessages = 0;

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        scheduledMessages += schedules.count;

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        [self.allSchedules addObjectsFromArray:schedules];

        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;

        [invocation getArgument:&arg atIndex:2];
        NSString *scheduleID = (__bridge NSString *)arg;

        [invocation getArgument:&arg atIndex:3];
        UAScheduleEdits *edits = (__bridge UAScheduleEdits *)arg;
        if ([edits.end isEqualToDate:inAppRemoteDataPayload.timestamp]) {
            cancelledMessages += 1;
        } else {
            editedMessages += 1;
        }

        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler([self getScheduleForScheduleId:scheduleID]);
    }] editScheduleWithID:OCMOCK_ANY edits:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);
    XCTAssertEqual(editedMessages, 0);

    // setup to delete one message
    scheduledMessages = 0;
    cancelledMessages = 0;
    editedMessages = 0;

    inAppMessages = @[message2];

    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              metadata:@{@"cool" : @"story"}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 0);
    XCTAssertEqual(cancelledMessages, 1);
    XCTAssertEqual(editedMessages, 0);
}

- (void)testOneChangedInAppMessage {
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
                                                                                  timestamp:[UAUtils parseISO8601DateFromString:@"2017-12-04T19:07:54.564"] // REVISIT - change this everywhere?
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   metadata:@{@"cool" : @"story"}];

    __block NSUInteger scheduledMessages = 0;
    __block NSUInteger cancelledMessages = 0;
    __block NSUInteger editedMessages = 0;
    __block UASchedule *schedule1;
    __block UASchedule *schedule2;

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        scheduledMessages += schedules.count;

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        for (UASchedule *schedule in schedules) {
            [self.allSchedules addObject:schedule];
            if ([schedule.identifier isEqualToString:message1ID]) {
                schedule1 = schedule;
            } else if ([schedule.identifier isEqualToString:message2ID]) {
                schedule2 = schedule;
            }
        }
        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;

        [invocation getArgument:&arg atIndex:3];
        UAScheduleEdits *edits = (__bridge UAScheduleEdits *)arg;
        if ([edits.end isEqualToDate:inAppRemoteDataPayload.timestamp]) {
            cancelledMessages += 1;
        } else if (edits.priority) {
            editedMessages += 1;
        }

        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(nil); // REVISIT - return schedule
    }] editScheduleWithID:OCMOCK_ANY edits:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);
    XCTAssertEqual(editedMessages, 0);

    // setup to change one message
    scheduledMessages = 0;
    cancelledMessages = 0;
    editedMessages = 0;

    NSMutableDictionary *changedMessage2 = [NSMutableDictionary dictionaryWithDictionary:message2];
    changedMessage2[@"priority"] = @1;
    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    NSString *now = [formatter stringFromDate:[NSDate date]];
    changedMessage2[@"last_updated"] = now;

    inAppMessages = @[message1, changedMessage2];
    inAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              metadata:@{@"cool" : @"story"}];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 0);
    XCTAssertEqual(cancelledMessages, 0);
    XCTAssertEqual(editedMessages, 1);
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
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   metadata:@{@"cool" : @"story"}];

    __block NSUInteger scheduledMessages = 0;
    __block NSUInteger cancelledMessages = 0;

    // expectations
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        scheduledMessages += schedules.count;

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray<UASchedule *> *) = (__bridge void (^)(NSArray<UASchedule *> *))arg;

        [self.allSchedules addObjectsFromArray:schedules];

        completionHandler(self.allSchedules);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        cancelledMessages += 1;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(nil);
    }] editScheduleWithID:OCMOCK_ANY edits:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);

    // setup empty payload
    UARemoteDataPayload *emptyInAppRemoteDataPayload = [[UARemoteDataPayload alloc] initWithType:@"in_app_messages"
                                                                                       timestamp:[NSDate date]
                                                                                            data:@{}
                                                                                        metadata:@{}];

    // test
    self.publishBlock(@[emptyInAppRemoteDataPayload]);
    [self.queue waitUntilAllOperationsAreFinished];

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(cancelledMessages, 2);
}

- (void)testNewUserCutoffTime {
    // verify
    NSDate *scheduleNewUserCutoffTime = [self.remoteDataClient.scheduleNewUserCutOffTime copy];
    XCTAssertEqualWithAccuracy([scheduleNewUserCutoffTime timeIntervalSinceNow], 0, 1, @"after first init, schedule new user cut off time should be approximately now");

    // test
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithRemoteDataProvider:self.mockRemoteDataProvider
                                                                        dataStore:self.dataStore
                                                                          channel:self.mockChannel];
    // verify
    XCTAssertEqualObjects(self.remoteDataClient.scheduleNewUserCutOffTime, scheduleNewUserCutoffTime, @"after second init, schedule new user cut off time should stay the same.");
}

- (void)testExistingUserCutoffTime {
    // start with empty data store (new app install)
    [self.dataStore removeAll];

    // an existing user already has a channelID
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel expect] andReturn:@"sample-channel-id"] identifier];

    // test
    self.remoteDataClient = [UAInAppRemoteDataClient clientWithRemoteDataProvider:self.mockRemoteDataProvider
                                                                        dataStore:self.dataStore
                                                                          channel:self.mockChannel];
    // verify
    XCTAssertEqualObjects(self.remoteDataClient.scheduleNewUserCutOffTime, [NSDate distantPast], @"existing users should get a cut-off time in the distant past");
}

- (void)testValidSchedule {
    id remoteDataMetadata = @{@"neat": @"rad"};
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": remoteDataMetadata
        };
    }];

    [[[self.mockRemoteDataProvider expect] andReturnValue:@(YES)] isMetadataCurrent:remoteDataMetadata];
    XCTAssertTrue([self.remoteDataClient isScheduleUpToDate:schedule]);
}

- (void)testInvalidSchedule {
    id remoteDataMetadata = @{@"neat": @"rad"};

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": remoteDataMetadata
        };
    }];

    [[[self.mockRemoteDataProvider expect] andReturnValue:@(NO)] isMetadataCurrent:remoteDataMetadata];
    XCTAssertFalse([self.remoteDataClient isScheduleUpToDate:schedule]);
}

- (void)testRemoteSchedule {
    id remoteDataMetadata = @{@"neat": @"rad"};

    UASchedule *remote = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": remoteDataMetadata
        };
    }];

    UASchedule *notRemote = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
    }];

    UAInAppMessage *remoteMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.identifier = @"neat";
        builder.source = UAInAppMessageSourceRemoteData;
    }];

    UASchedule *legacyRemote = [UAInAppMessageSchedule scheduleWithMessage:remoteMessage builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
    }];

    XCTAssertFalse([self.remoteDataClient isRemoteSchedule:notRemote]);
    XCTAssertTrue([self.remoteDataClient isRemoteSchedule:remote]);
    XCTAssertTrue([self.remoteDataClient isRemoteSchedule:legacyRemote]);

}

- (UASchedule *)getScheduleForScheduleId:(NSString *)scheduleId {
    for (UASchedule *schedule in self.allSchedules) {
        if ([scheduleId isEqualToString:schedule.identifier]) {
            return schedule;
        }
    }
    return nil;
}


@end

