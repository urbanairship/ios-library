/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleEdits+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAActionSchedule.h"
#import "UAInappMessageSchedule.h"
#import "UADeferredSchedule+Internal.h"
#import "UAInAppMessageCustomDisplayContent.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAInAppRemoteDataClientTest : UAAirshipBaseTest
@property (nonatomic,strong) UAInAppRemoteDataClient *remoteDataClient;
@property (nonatomic, copy) void (^publishBlock)(NSArray<UARemoteDataPayload *> *);

@property (nonatomic, strong) id mockRemoteData;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockChannel;

@property (nonatomic, strong) NSMutableArray<UASchedule *> *allSchedules;
@end

@implementation UAInAppRemoteDataClientTest

- (void)setUp {
    [super setUp];

    // mock remote data
    self.mockRemoteData = [self mockForClass:[UARemoteDataAutomationAccess class]];
    [[[self.mockRemoteData stub] andDo:^(NSInvocation *invocation) {
        void *arg;

        // verify payload types
        [invocation getArgument:&arg atIndex:2];
        NSArray<NSString *> *types = (__bridge NSArray<NSString *> *)arg;
        XCTAssertTrue(types.count == 1);
        XCTAssertTrue([types containsObject:@"in_app_messages"]);

        // verify and check publishBlock
        [invocation getArgument:&arg atIndex:3];
        self.publishBlock = (__bridge void (^)(NSArray *))arg;
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

    self.remoteDataClient = [UAInAppRemoteDataClient clientWithRemoteData:self.mockRemoteData
                                                                dataStore:self.dataStore
                                                                  channel:self.mockChannel
                                                      schedulerDispatcher:[[UATestDispatcher alloc] init]
                                                               SDKVersion:@"0.0.0"];
    self.remoteDataClient.delegate = self.mockDelegate;

    [self.remoteDataClient subscribe];
    XCTAssertNotNil(self.publishBlock);
}

- (void)testMetadataChange {
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
                                    @"product_id": @"test product id",
                                    @"triggers": @[
                                            @{
                                                @"type":@"app_init",
                                                @"goal":@1
                                            }
                                    ]
    };

    NSArray *inAppMessages = @[simpleMessage];
    NSUInteger expectedNumberOfSchedules = inAppMessages.count;
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   source:UARemoteDataSourceApp
                                                                                  lastModified:@"last modified a"];

    // expectations
    __block NSUInteger callsToScheduleMessages = 0;
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        callsToScheduleMessages++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;

        for (UASchedule *schedule in schedules) {
            XCTAssertEqualObjects([self.remoteDataClient remoteDataInfoFromSchedule:schedule], inAppRemoteDataPayload.remoteDataInfo);
            XCTAssertEqual(@"test product id", schedule.productId);
        }

        XCTAssertEqual(schedules.count, expectedNumberOfSchedules);

        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        [self.allSchedules addObjectsFromArray:schedules];
        completionHandler(YES);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages, 1);



    inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              source:UARemoteDataSourceApp
                                                             lastModified:@"last modified b"];


    XCTestExpectation *editCalled = [self expectationWithDescription:@"Edit call should be made for metadata change"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(self.allSchedules[0]);
        [editCalled fulfill];
    }] editScheduleWithID:self.allSchedules[0].identifier edits:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAScheduleEdits *edits = obj;
        id info = [UARemoteDataInfo fromJSONWithString:edits.metadata[@"com.urbanairship.iaa.REMOTE_DATA_INFO"] error:nil];
        return [info isEqual:inAppRemoteDataPayload.remoteDataInfo];
    }] completionHandler:OCMOCK_ANY];

    // setup to same message with metadata B

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
}

- (void)testEmptyInAppMessageList {
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                     timestamp:[NSDate date]
                                                                                          data:@{@"in_app_messages":@[]}
                                                                                      source:UARemoteDataSourceApp];

    [[self.mockDelegate reject] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
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

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                     timestamp:[NSDate date]
                                                                                          data:@{@"in_app_messages":@[simpleMessage]}
                                                                                        source:UARemoteDataSourceApp];


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
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                        source:UARemoteDataSourceApp];

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
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                        source:UARemoteDataSourceApp];

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

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(callsToScheduleMessages,1);

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

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

    __block UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                          timestamp:[NSDate date]
                                                                                               data:@{@"in_app_messages":inAppMessages}
                                                                                           source:UARemoteDataSourceApp];
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

    inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              source:UARemoteDataSourceApp];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

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
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[UAUtils parseISO8601DateFromString:@"2017-12-04T19:07:54.564"] // REVISIT - change this everywhere?
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   source:UARemoteDataSourceApp];

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
    inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              source:UARemoteDataSourceApp];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 0);
    XCTAssertEqual(cancelledMessages, 0);
    XCTAssertEqual(editedMessages, 1);
}

- (void)testDefaultEdits {
    // setup to add messages
    NSString *messageID = [NSUUID UUID].UUIDString;
    NSDictionary *message = @{@"message": @{
                                      @"name": @"Simple Message",
                                      @"message_id": messageID,
                                      @"display_type": @"banner",
                                      @"limit": @(100),
                                      @"edit_grace_period": @(28),
                                      @"frequency_constraint_ids": @[@"neat"],
                                      @"campaigns": @{ @"neat": @"campaign" },
                                      @"priority": @(-100),
                                      @"interval": @(200),
                                      @"start": @"2000-12-04T19:07:54.564",
                                      @"end": @"3000-12-04T19:07:54.564",
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

    NSArray *inAppMessages = @[message];
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[UAUtils parseISO8601DateFromString:@"2017-12-04T19:07:54.564"] // REVISIT - change this everywhere?
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   source:UARemoteDataSourceApp];

    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSArray<UASchedule *> *schedules = (__bridge NSArray<UASchedule *> *)arg;
        [self.allSchedules addObjectsFromArray:schedules];
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    NSString *now = [formatter stringFromDate:[NSDate date]];
    message = @{@"message": @{
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
                @"product_id": @"another product id",
                @"last_updated": now,
                @"triggers": @[
                        @{
                            @"type":@"app_init",
                            @"goal":@1
                        }
                ]
    };

    inAppMessages = @[message];
    inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                             timestamp:[NSDate date]
                                                                  data:@{@"in_app_messages":inAppMessages}
                                                              source:UARemoteDataSourceApp];

    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UASchedule *) = (__bridge void (^)(UASchedule *))arg;
        completionHandler(nil);
    }] editScheduleWithID:messageID edits:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAScheduleEdits *edits = obj;
        return edits.editGracePeriod.doubleValue == (14 * 60 * 60 * 24) &&
        edits.campaigns && edits.campaigns.count == 0 &&
        edits.frequencyConstraintIDs  && edits.frequencyConstraintIDs.count == 0 &&
        edits.limit && edits.limit.integerValue == 1 &&
        edits.interval && edits.interval.doubleValue == 0 &&
        edits.priority && edits.priority.integerValue == 0 &&
        [edits.start isEqual:[NSDate distantPast]] &&
        [edits.end isEqual:[NSDate distantFuture]] &&
        [edits.productId isEqualToString: @"another product id"];
    }] completionHandler:OCMOCK_ANY];

    // test
    self.publishBlock(@[inAppRemoteDataPayload]);

    // verify
    [self.mockDelegate verify];
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
    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":inAppMessages}
                                                                                   source:UARemoteDataSourceApp];

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

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(scheduledMessages, 2);
    XCTAssertEqual(cancelledMessages, 0);

    // setup empty payload
    UARemoteDataPayload *emptyInAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                          timestamp:[NSDate date]
                                                                                               data:@{}
                                                                                               source:UARemoteDataSourceApp];

    // test
    self.publishBlock(@[emptyInAppRemoteDataPayload]);

    // verify
    [self.mockDelegate verify];
    XCTAssertEqual(cancelledMessages, 2);
}

- (void)testLegacyMessage {
    id payload = @{
        @"message": @{
                @"name": @"Simple Message",
                @"display_type": @"custom",
                @"display": @{
                        @"custom": @{
                                @"custom": @"stuff"
                        }
                },
                @"audience": @{
                        @"notification_opt_in": @(YES)
                },
                @"message_id": @"some id"
        },
        @"created": @"2017-12-04T19:07:54.564",
        @"last_updated": @"2017-12-04T19:07:54.564",
        @"triggers": @[
                @{
                    @"type":@"app_init",
                    @"goal":@1
                }
        ],
        @"edit_grace_period": @(14),
        @"delay":  @{
                @"seconds": @(100),
                @"cancellation_triggers": @[
                        @{
                            @"type":@"app_init",
                            @"goal":@2
                        }
                ]
        },
        @"group": @"some group",
        @"interval": @(60),
        @"priority": @(-30)
    };

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"custom": @"stuff"}];
        builder.name = @"Simple Message";
        builder.source = UAInAppMessageSourceRemoteData;
    }];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[payload]}
                                                                                        source:UARemoteDataSourceApp];

    UASchedule *expected = [UAInAppMessageSchedule scheduleWithMessage:message
                                                          builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.audienceJSON = payload[@"audience"];
        builder.identifier = @"some id";
        builder.triggers = @[[UAScheduleTrigger appInitTriggerWithCount:1]];
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": @{},
            @"com.urbanairship.iaa.REMOTE_DATA_INFO": [inAppRemoteDataPayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil]
        };

        // Edit grace period should be converted to seconds
        builder.editGracePeriod = 14 * 60 * 60 * 24;

        builder.delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder *builder) {
            builder.cancellationTriggers = @[[UAScheduleTrigger appInitTriggerWithCount:2]];
            builder.seconds = 100;
        }];
        builder.group = @"some group";
        builder.interval = 60;
        builder.priority = -30;


        builder.isNewUserEvaluationDate = [UAUtils parseISO8601DateFromString:payload[@"created"]];

    }];



    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
        [scheduled fulfill];
    }] scheduleMultiple:@[expected] completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self waitForTestExpectations];
    [self.mockDelegate verify];
}

- (void)testActionsSchedule {
    id payload = @{
        @"actions": @{
                @"some action name": @"some action value"
        },
        @"type": @"actions",
        @"created": @"2017-12-04T19:07:54.564",
        @"last_updated": @"2017-12-04T19:07:54.564",
        @"triggers": @[
                @{
                    @"type":@"app_init",
                    @"goal":@1
                }
        ],
        @"id": @"some id",
        @"edit_grace_period": @(14),
        @"delay":  @{
                @"seconds": @(100),
                @"cancellation_triggers": @[
                        @{
                            @"type":@"app_init",
                            @"goal":@2
                        }
                ]
        },
        @"audience": @{
                @"notification_opt_in": @(YES)
        },
        @"group": @"some group",
        @"interval": @(60),
        @"priority": @(-30)
    };

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[payload]}
                                                                                   source:UARemoteDataSourceApp];


    UASchedule *expected = [UAActionSchedule scheduleWithActions:@{@"some action name": @"some action value"}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.audienceJSON = payload[@"audience"];
        builder.identifier = @"some id";
        builder.triggers = @[[UAScheduleTrigger appInitTriggerWithCount:1]];
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": @{},
            @"com.urbanairship.iaa.REMOTE_DATA_INFO": [inAppRemoteDataPayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil]
        };

        // Edit grace period should be converted to seconds
        builder.editGracePeriod = 14 * 60 * 60 * 24;

        builder.delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder *builder) {
            builder.cancellationTriggers = @[[UAScheduleTrigger appInitTriggerWithCount:2]];
            builder.seconds = 100;
        }];
        builder.group = @"some group";
        builder.interval = 60;
        builder.priority = -30;
        builder.isNewUserEvaluationDate = [UAUtils parseISO8601DateFromString:@"2017-12-04T19:07:54.564"];
    }];


    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
        [scheduled fulfill];
    }] scheduleMultiple:@[expected] completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self waitForTestExpectations];
    [self.mockDelegate verify];
}

- (void)testDeferredSchedule {
    id payload = @{
        @"deferred": @{
                @"url": @"https://airship.com/example",
                @"retry_on_timeout": @(YES)
        },
        @"type": @"deferred",
        @"created": @"2017-12-04T19:07:54.564",
        @"last_updated": @"2017-12-04T19:07:54.564",
        @"triggers": @[
                @{
                    @"type":@"app_init",
                    @"goal":@1
                }
        ],
        @"id": @"some id",
        @"audience": @{
                @"notification_opt_in": @(YES)
        }
    };


    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com/example"]
                                                                retriableOnTimeout:YES];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[payload]}
                                                                                        source:UARemoteDataSourceApp];

    UASchedule *expected = [UADeferredSchedule scheduleWithDeferredData:deferred
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.audienceJSON = payload[@"audience"];
        builder.identifier = @"some id";
        builder.triggers = @[[UAScheduleTrigger appInitTriggerWithCount:1]];
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": @{},
            @"com.urbanairship.iaa.REMOTE_DATA_INFO": [inAppRemoteDataPayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil]
        };
        builder.isNewUserEvaluationDate = [UAUtils parseISO8601DateFromString:payload[@"created"]];
    }];



    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
        [scheduled fulfill];
    }] scheduleMultiple:@[expected] completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self waitForTestExpectations];
    [self.mockDelegate verify];
}

- (void)testMinSDKVersion {
    NSDate *date = [NSDate date];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                     timestamp:date
                                                                                          data:@{@"in_app_messages":@[@{}]}
                                                                                        source:UARemoteDataSourceApp];

    self.publishBlock(@[inAppRemoteDataPayload]);

    [self.remoteDataClient unsubscribe];

    self.remoteDataClient = [UAInAppRemoteDataClient clientWithRemoteData:self.mockRemoteData
                                                                dataStore:self.dataStore
                                                                  channel:self.mockChannel
                                                      schedulerDispatcher:[[UATestDispatcher alloc] init]
                                                               SDKVersion:@"1.0.0"];
    self.remoteDataClient.delegate = self.mockDelegate;

    [self.remoteDataClient subscribe];

    id payload = @{
        @"min_sdk_version": @"1.0.0",
        @"message": @{
                @"name": @"Simple Message",
                @"display_type": @"custom",
                @"display": @{
                        @"custom": @{
                                @"custom": @"stuff"
                        }
                }
        },
        @"campaigns": @{ @"categories": @[@"cool"] },
        @"type": @"in_app_message",
        @"created": @"2017-12-04T19:07:54.564",
        @"last_updated": @"2017-12-04T19:07:54.564",
        @"triggers": @[
                @{
                    @"type":@"app_init",
                    @"goal":@1
                }
        ],
        @"id": @"some id",
        @"audience": @{
                @"notification_opt_in": @(YES)
        },
        @"frequency_constraint_ids": @[@"constraint-one"],
    };

    inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                             timestamp:[date dateByAddingTimeInterval:1000]
                                                                  data:@{@"in_app_messages":@[payload]}
                                                                   source:UARemoteDataSourceApp
                                                                lastModified:@"some timestamp"];


    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
        [scheduled fulfill];
    }] scheduleMultiple:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self waitForTestExpectations];
    [self.mockDelegate verify];
}

- (void)testInAppMessageSchedule {
    id payload = @{
        @"message": @{
                @"name": @"Simple Message",
                @"display_type": @"custom",
                @"display": @{
                        @"custom": @{
                                @"custom": @"stuff"
                        }
                }
        },
        @"campaigns": @{ @"categories": @[@"cool"] },
        @"type": @"in_app_message",
        @"created": @"2017-12-04T19:07:54.564",
        @"last_updated": @"2017-12-04T19:07:54.564",
        @"triggers": @[
                @{
                    @"type":@"app_init",
                    @"goal":@1
                }
        ],
        @"id": @"some id",
        @"audience": @{
                @"notification_opt_in": @(YES)
        },
        @"frequency_constraint_ids": @[@"constraint-one"],
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"custom": @"stuff"}];
        builder.name = @"Simple Message";
        builder.source = UAInAppMessageSourceRemoteData;
    }];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"in_app_messages":@[payload]}
                                                                                        source:UARemoteDataSourceApp];


    UASchedule *expected = [UAInAppMessageSchedule scheduleWithMessage:message
                                                          builderBlock:^(UAScheduleBuilder * _Nonnull builder) {

        builder.audienceJSON = payload[@"audience"];
        builder.identifier = @"some id";
        builder.triggers = @[[UAScheduleTrigger appInitTriggerWithCount:1]];
        builder.metadata = @{
            @"com.urbanairship.iaa.REMOTE_DATA_METADATA": @{},
            @"com.urbanairship.iaa.REMOTE_DATA_INFO": [inAppRemoteDataPayload.remoteDataInfo toEncodedJSONStringAndReturnError:nil]
        };
        builder.campaigns = @{ @"categories": @[@"cool"] };
        builder.frequencyConstraintIDs = @[@"constraint-one"];
        builder.isNewUserEvaluationDate = [UAUtils parseISO8601DateFromString:payload[@"created"]];
    }];


    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
        [scheduled fulfill];
    }] scheduleMultiple:@[expected] completionHandler:OCMOCK_ANY];

    self.publishBlock(@[inAppRemoteDataPayload]);
    [self waitForTestExpectations];
    [self.mockDelegate verify];
}

- (void)testEmptyConstraints {
    [[self.mockDelegate expect] updateConstraints:@[]];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{}
                                                                                   source:UARemoteDataSourceApp];
    self.publishBlock(@[inAppRemoteDataPayload]);

    [self.mockDelegate verify];
}

- (void)testConstraints {
    id periodMap = @{
        @"seconds": @(1),
        @"minutes": @(60),
        @"hours": @(60 * 60),
        @"days": @(60 * 60 * 24),
        @"weeks": @(60 * 60 * 24 * 7),
        @"months": @(60 * 60 * 24 * 30),
        @"years": @(60 * 60 * 24 * 365),
    };

    NSMutableArray *constraintPayloads = [NSMutableArray array];
    NSMutableArray *expectedConstraints = [NSMutableArray array];

    for (NSString *period in periodMap) {
        NSString *constraintId = [NSString stringWithFormat:@"%@ id", period];
        id paylaod = @{
            @"id": constraintId,
            @"boundary": @(10),
            @"range": @(10),
            @"period": period
        };
        [constraintPayloads addObject:paylaod];



        UAFrequencyConstraint *constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:constraintId
                                                                                               range: 10 * [periodMap[period] doubleValue]
                                                                                               count:10];
        [expectedConstraints addObject:constraint];
    }

    [[self.mockDelegate expect] updateConstraints:expectedConstraints];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"frequency_constraints": constraintPayloads}
                                                                                   source:UARemoteDataSourceApp];
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.mockDelegate verify];
}


- (void)testInvalidConstraint {
    NSArray *constraintPayloads = @[@{ @"id": @"valid",
                                       @"boundary": @(10),
                                       @"range": @(10),
                                       @"period": @"seconds" },
                                    @{ @"id": @"missing period",
                                       @"boundary": @(10),
                                       @"range": @(10) },
                                    @{ @"id": @"missing range",
                                       @"boundary": @(10),
                                       @"period": @"seconds" },
                                    @{ @"id": @"missing boundary",
                                       @"range": @(10),
                                       @"period": @"seconds" },
                                    @{ @"boundary": @(10),
                                       @"range": @(10),
                                       @"period": @"seconds" },
                                    @{ @"id": @"invalid range",
                                       @"boundary": @(10),
                                       @"range": @(10),
                                       @"period": @"lightyears" }];

    UAFrequencyConstraint *expected = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"valid" range:10 count:10];

    [[self.mockDelegate expect] updateConstraints:@[expected]];

    UARemoteDataPayload *inAppRemoteDataPayload = [RemoteDataTestUtils generatePayloadWithType:@"in_app_messages"
                                                                                  timestamp:[NSDate date]
                                                                                       data:@{@"frequency_constraints": constraintPayloads}
                                                                                   source:UARemoteDataSourceApp];
    self.publishBlock(@[inAppRemoteDataPayload]);
    [self.mockDelegate verify];
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

