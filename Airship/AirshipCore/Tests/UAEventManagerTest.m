/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAEventManager+Internal.h"
#import "UAEventStore+Internal.h"
#import "UARuntimeConfig.h"
#import "UACustomEvent.h"
#import "UARegionEvent.h"
#import "UAirship+Internal.h"
#import "UAChannel.h"
#import "UATaskManager.h"

@import AirshipCore;

static NSString * const UAEventManagerUploadTask = @"UAEventManager.upload";

/**
 * Test event data class to work around not being able to mock UAEventData
 */
@interface UAEventTestData : NSObject
@property (nullable, nonatomic, copy) NSString *sessionID;
@property (nullable, nonatomic, copy) NSData *data;
@property (nullable, nonatomic, copy) NSString *time;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSString *identifier;
@property (nullable, nonatomic, strong) NSNumber *bytes;
@end

@implementation UAEventTestData
@end

@interface UAEventManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAEventManager *eventManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) id mockClient;
@property (nonatomic, strong) id mockStore;
@property (nonatomic, strong) id mockAppStateTracker;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockTaskManager;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@property(nonatomic, copy) UADelay *(^delayProvider)(NSTimeInterval);
@end

@implementation UAEventManagerTest

- (void)setUp {
    [super setUp];

    self.mockClient = [self mockForClass:[UAEventAPIClient class]];
    self.mockStore = [self mockForClass:[UAEventStore class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockAppStateTracker = [self mockForClass:[UAAppStateTracker class]];
    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithID:UAEventManagerUploadTask dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.delayProvider = ^(NSTimeInterval delay) {
        return [[UADelay alloc] init:0];
    };

    self.eventManager = [UAEventManager eventManagerWithConfig:self.config
                                                     dataStore:self.dataStore
                                                       channel:self.mockChannel
                                                    eventStore:self.mockStore
                                                        client:self.mockClient
                                            notificationCenter:self.notificationCenter
                                               appStateTracker:self.mockAppStateTracker
                                                   taskManager:self.mockTaskManager
                                                 delayProvider:^(NSTimeInterval delay){
        return self.delayProvider(delay);
    }];

    self.mockDelegate = [self mockForProtocol:@protocol(UAEventManagerDelegate)];
    self.eventManager.delegate = self.mockDelegate;
    self.eventManager.uploadsEnabled = YES;
}

/*
 * Test deleting all events.
 */
- (void)testDeleteAllEvents {
    [[self.mockStore expect] deleteAllEvents];

    [self.eventManager deleteAllEvents];

    [self.mockClient verify];
    [self.mockStore verify];
}

/**
 * Test adding an event.
 */
- (void)testAddEventInitialDelay {
    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[self.mockStore expect] saveEvent:event sessionID:@"story"];
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:15];

    [self.eventManager addEvent:event sessionID:@"story"];

    [self.mockStore verify];
    [self.mockTaskManager verify];
}

/**
 * Test adding an event in the background defaults schedules immediately
 */
- (void)testAddEventBackground {
    // Background application state
    [[[self.mockAppStateTracker stub] andReturnValue:@(UAApplicationStateBackground)] state];

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[self.mockStore expect] saveEvent:event sessionID:@"story"];
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:0];

    [self.eventManager addEvent:event sessionID:@"story"];

    [self.mockStore verify];
    [self.mockTaskManager verify];
}

/**
 * Test adding an event when uploads are disabled.
 */
- (void)testAddEventWhenUploadsAreDisabled {
    self.eventManager.uploadsEnabled = NO;

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[[self.mockTaskManager reject] ignoringNonObjectArgs] enqueueRequestWithID:OCMOCK_ANY
                                                                        options:OCMOCK_ANY
                                                                   initialDelay:0];
    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    [self.eventManager addEvent:event sessionID:@"story"];

    [self.mockStore verify];
    [self.mockTaskManager verify];
}

/**
 * Test adding a high priority event schedules a task with 0 second delay.
 */
- (void)testAddHighPriorityEvent {
    UARegionEvent *event = [[UARegionEvent alloc] init];

    [[self.mockStore expect] saveEvent:event sessionID:@"story"];
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:0];

    [self.eventManager addEvent:event sessionID:@"story"];

    [self.mockStore verify];
    [self.mockTaskManager verify];
}


/**
 * Test entering background schedules an upload immediately.
 */
- (void)testBackground {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:0];
    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];
    [self.mockTaskManager verify];
}

/**
 * Test creating a channel schedules an upload.
 */
- (void)testChannelCreated {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:15];

    [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                           object:nil];

    [self.mockTaskManager verify];
}

/**
 * Test scheduling an upload with an earlier time will cancel the current operations.
 */
- (void)testRescheduleUpload {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:15];

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];
    [self.eventManager addEvent:event sessionID:@"story"];
    [self.mockTaskManager verify];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:0];

    UARegionEvent *regionEvent = [[UARegionEvent alloc] init];
    [self.eventManager addEvent:regionEvent sessionID:@"story"];

    [self.mockTaskManager verify];
}

/**
 * Test uploading events.
 */
- (void)testScheduleUpload {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    // Set  up a mock event data
    UAEventTestData *eventData = [[UAEventTestData alloc] init];
    eventData.type = @"mock_event";
    eventData.time = @"100";
    eventData.identifier = @"mock_event_id";
    eventData.sessionID = @"mock_event_session";
    eventData.data = [NSJSONSerialization dataWithJSONObject:@{@"cool": @"story"} options:0 error:nil];

    // Stub the event store to return the data
    [[[[self.mockStore expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^returnBlock)(NSArray *result)= (__bridge void (^)(NSArray *))arg;
        returnBlock(@[eventData]);
    }] ignoringNonObjectArgs] fetchEventsWithLimit:500 completionHandler:OCMOCK_ANY];

    NSDictionary *headers = @{@"header": @"headerValue"};
    [[[self.mockDelegate stub] andReturn:headers] analyticsHeaders];

    XCTestExpectation *clientCalled = [self expectationWithDescription:@"client upload callled."];

    // Expect a call to the client, return a successful response
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^returnBlock)(UAEventAPIResponse *, NSError *)= (__bridge void (^)(UAEventAPIResponse *, NSError *))arg;

        // Return a successful response
        returnBlock([[UAEventAPIResponse alloc] initWithStatus:200 maxTotalDBSize:@(123) maxBatchSize:@(234) minBatchInterval:@(345)], nil);
        [clientCalled fulfill];
    }] uploadEvents:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *events = (NSArray *)obj;
        if (events.count != 1) {
            return NO;
        }

        if (![events[0][@"event_id"] isEqualToString:@"mock_event_id"]) {
            return NO;
        }

        if (![events[0][@"time"] isEqualToString:@"100"]) {
            return NO;
        }

        if (![events[0][@"type"] isEqualToString:@"mock_event"]) {
            return NO;
        }

        NSDictionary *expectedData = @{@"cool": @"story", @"session_id": @"mock_event_session"};
        if (![events[0][@"data"] isEqual:expectedData]) {
            return NO;
        }

        return YES;
    }] headers:headers completionHandler:OCMOCK_ANY];

    // Expect the store to delete the event
    [[self.mockStore expect] deleteEventsWithIDs:@[@"mock_event_id"]];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[mockTask expect] taskCompleted];

    // End of the upload another upload should be scheduled
    XCTestExpectation *uploadScheduled = [self expectationWithDescription:@"upload scheduled"];
    [[[[self.mockTaskManager expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [uploadScheduled fulfill];
    }] enqueueRequestWithID:UAEventManagerUploadTask options:OCMOCK_ANY initialDelay:0];

    // Start the upload
    self.launchHandler(mockTask);

    [self waitForTestExpectations];
    [self.mockClient verify];
    [self.mockStore verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}


/**
 * Test batch limit.
 */
- (void)testBatchLimit {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    NSMutableArray *events = [NSMutableArray array];
    for (int i = 0; i <= 1000; i++) {
        UAEventTestData *eventData = [[UAEventTestData alloc] init];
        eventData.type = @"mock_event";
        eventData.time = @"100";
        eventData.identifier = [NSString stringWithFormat:@"event: %d", i];
        eventData.sessionID = @"mock_event_session";
        eventData.data = [NSJSONSerialization dataWithJSONObject:@{@"cool": @"story"} options:0 error:nil];
        eventData.bytes = @(2048);
        [events addObject:eventData];
    }

    // Only the first 500 events will be uploaded
    NSMutableArray *expectedEventIDs = [[events subarrayWithRange:NSMakeRange(0, 250)] valueForKey:@"identifier"];

    // Stub the event store to return the data
    [[[[self.mockStore expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^returnBlock)(NSArray *result)= (__bridge void (^)(NSArray *))arg;
        returnBlock(events);
    }] ignoringNonObjectArgs] fetchEventsWithLimit:500 completionHandler:OCMOCK_ANY];

    NSDictionary *headers = @{@"header": @"headerValue"};
    [[[self.mockDelegate stub] andReturn:headers] analyticsHeaders];

    XCTestExpectation *clientCalled = [self expectationWithDescription:@"client upload callled."];

    // Expect a call to the client, return a successful response
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^returnBlock)(UAEventAPIResponse *, NSError *)= (__bridge void (^)(UAEventAPIResponse *, NSError *))arg;

        // Return a successful response
        returnBlock([[UAEventAPIResponse alloc] initWithStatus:200 maxTotalDBSize:@(123) maxBatchSize:@(234) minBatchInterval:@(345)], nil);
        [clientCalled fulfill];
    }] uploadEvents:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSArray *uploadedEventIDs = [(NSArray *)obj valueForKey:@"event_id"];
        return [uploadedEventIDs isEqualToArray:expectedEventIDs];
    }] headers:headers completionHandler:OCMOCK_ANY];

    // Expect the store to delete the event
    [[self.mockStore expect] deleteEventsWithIDs:expectedEventIDs];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[mockTask expect] taskCompleted];

    // Start the upload
    self.launchHandler(mockTask);

    [self waitForTestExpectations];
    [self.mockClient verify];
    [self.mockStore verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

/**
 * Test uploading events when uploads are disabled.
 */
- (void)testScheduleUploadWhenUploadsAreDisabled {
    // setup
    self.eventManager.uploadsEnabled = NO;

    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    // Reject any calls to the store
    [[[self.mockStore reject] ignoringNonObjectArgs] fetchEventsWithLimit:0 completionHandler:OCMOCK_ANY];

    // Reject any calls to the client
    [[self.mockClient reject] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    [self.eventManager scheduleUpload];

    // Start the upload
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[mockTask expect] taskCompleted];
    self.launchHandler(mockTask);

    // verify
    [self.mockClient verify];
    [self.mockStore verify];
    [mockTask verify];
}

/**
 * Test failed upload rescheduling an upload.
 */
- (void)testRetryFailedUpload {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    // Set  up a mock event data
    UAEventTestData *eventData = [[UAEventTestData alloc] init];
    eventData.type = @"mock_event";
    eventData.time = @"100";
    eventData.identifier = @"mock_event_id";
    eventData.sessionID = @"mock_event_session";
    eventData.data = [NSJSONSerialization dataWithJSONObject:@{@"cool": @"story"} options:0 error:nil];

    // Stub the event store to return the data
    [[[[self.mockStore expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^returnBlock)(NSArray *result)= (__bridge void (^)(NSArray *))arg;
        returnBlock(@[eventData]);
    }] ignoringNonObjectArgs] fetchEventsWithLimit:0 completionHandler:OCMOCK_ANY];

    // Expect a call to the client, return an unsuccesful response
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^returnBlock)(NSDictionary *, NSError *)= (__bridge void (^)(NSDictionary *, NSError *))arg;

        // Return an error
        returnBlock(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{}]);
    }] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Expect the store to delete the event
    [[self.mockStore reject] deleteEventsWithIDs:OCMOCK_ANY];

    // Start the upload
    [self.eventManager scheduleUpload];

    // Start the upload
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[mockTask expect] taskFailed];
    self.launchHandler(mockTask);

    // Verify
    [self.mockClient verify];
    [self.mockStore verify];
    [mockTask verify];
}

/**
 * Test uploading no-ops if the channel is not available.
 */
- (void)testUploadNoChannel {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:nil] identifier];

    // Reject store and client calls
    [[[self.mockStore reject] ignoringNonObjectArgs] fetchEventsWithLimit:0 completionHandler:OCMOCK_ANY];
    [[self.mockClient reject] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Start the upload
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[mockTask expect] taskCompleted];
    self.launchHandler(mockTask);

    [self.mockClient verify];
    [self.mockStore verify];
    [mockTask verify];
}

/**
 * Test batch delay foreground.
 */
- (void)testBatchDelayForeground {
    [[[self.mockAppStateTracker stub] andReturnValue:@(UAApplicationStateActive)] state];

    id mockDelay = [self mockForClass:[UADelay class]];
    self.delayProvider = ^(NSTimeInterval delay) {
        XCTAssertEqual(delay, 1);
        return mockDelay;
    };

    [(UADelay *)[mockDelay expect] start];

    // Start the upload
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    self.launchHandler(mockTask);
    [mockDelay verify];
}

/**
 * Test batch delay background.
 */
- (void)testBatchDelayBackground {
    [[[self.mockAppStateTracker stub] andReturnValue:@(UAApplicationStateBackground)] state];

    id mockDelay = [self mockForClass:[UADelay class]];
    self.delayProvider = ^(NSTimeInterval delay) {
        XCTAssertEqual(delay, 5);
        return mockDelay;
    };

    [(UADelay *)[mockDelay expect] start];

    // Start the upload
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    self.launchHandler(mockTask);

    [mockDelay verify];
}

@end



