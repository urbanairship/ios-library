/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;
@import CoreData;

static NSString * const UAEventManagerUploadTask = @"UAEventManager.upload";

@interface UAEventManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAEventManager *eventManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) id mockClient;
@property (nonatomic, strong) id mockStore;
@property (nonatomic, strong) UATestAppStateTracker *testAppStateTracker;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) UATestTaskManager *testTaskManager;
@property(nonatomic, copy) UADelay *(^delayProvider)(NSTimeInterval);
@property(nonatomic, strong) NSManagedObjectContext *coreDataContext;
@end

@implementation UAEventManagerTest

- (void)setUp {
    [super setUp];

    self.mockClient = [self mockForClass:[UAEventAPIClient class]];
    self.mockStore = [self mockForProtocol:@protocol(UAEventStoreProtocol)];
    self.mockChannel = [self mockForProtocol:@protocol(UAChannelProtocol)];
    self.testAppStateTracker = [[UATestAppStateTracker alloc] init];
    self.testAppStateTracker.currentState = UAApplicationStateActive;
    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.testTaskManager = [[UATestTaskManager alloc] init];

    self.delayProvider = ^(NSTimeInterval delay) {
        return [[UADelay alloc] init:0];
    };

    self.eventManager = [[UAEventManager alloc] initWithConfig:self.config
                                                     dataStore:self.dataStore
                                                       channel:self.mockChannel
                                                    eventStore:self.mockStore
                                                        client:self.mockClient
                                            notificationCenter:self.notificationCenter
                                               appStateTracker:self.testAppStateTracker
                                                   taskManager:self.testTaskManager
                                                 delayProvider:^(NSTimeInterval delay){
        return self.delayProvider(delay);
    }];

    self.mockDelegate = [self mockForProtocol:@protocol(UAEventManagerDelegate)];
    self.eventManager.delegate = self.mockDelegate;
    self.eventManager.uploadsEnabled = YES;
    self.coreDataContext = [self createCoreDataContext];
}

- (NSManagedObjectContext *)createCoreDataContext {
    NSURL *momRUL = [[UAirshipCoreResources bundle] URLForResource:@"UAEvents" withExtension:@"momd"];
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momRUL];
    NSPersistentContainer *container = [[NSPersistentContainer alloc] initWithName:@"UAEvents" managedObjectModel:mom];

    NSPersistentStoreDescription *description = [[NSPersistentStoreDescription alloc] init];
    description.type = NSInMemoryStoreType;

    container.persistentStoreDescriptions = @[description];
    [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription * _Nonnull desc, NSError * _Nullable err) {}];

    return [container newBackgroundContext];
}

- (UAEventData *)createEventData {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"UAEventData" inManagedObjectContext:self.coreDataContext];
    return [[UAEventData alloc] initWithEntity:entity insertIntoManagedObjectContext:self.coreDataContext];
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
    NSDate *date = [NSDate now];
    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[self.mockStore expect] save:event eventID:@"neat" eventDate:date sessionID:@"story"];

    [self.eventManager add:event eventID:@"neat" eventDate:date sessionID:@"story"];

    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertTrue(task.completed);
    XCTAssertEqual(task.initialDelay, 15);

    [self.mockStore verify];
}

/**
 * Test adding an event in the background defaults schedules immediately
 */
- (void)testAddEventBackground {
    // Background application state
    self.testAppStateTracker.currentState = UAApplicationStateBackground;

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];
    NSDate *date = [NSDate now];

    [[self.mockStore expect] save:event eventID:@"neat" eventDate:date sessionID:@"story"];

    [self.eventManager add:event eventID:@"neat" eventDate:date sessionID:@"story"];

    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertTrue(task.completed);
    XCTAssertEqual(task.initialDelay, 0);

    [self.mockStore verify];
}

/**
 * Test adding an event when uploads are disabled.
 */
- (void)testAddEventWhenUploadsAreDisabled {
    self.eventManager.uploadsEnabled = NO;

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];
    NSDate *date = [NSDate now];

    [[self.mockStore expect] save:event eventID:@"neat" eventDate:date sessionID:@"story"];

    [self.eventManager add:event eventID:@"neat" eventDate:date sessionID:@"story"];

    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertFalse(task.completed);
    XCTAssertEqual(task.initialDelay, 0);

    [self.mockStore verify];
}

/**
 * Test adding a high priority event schedules a task with 0 second delay.
 */
- (void)testAddHighPriorityEvent {
    UARegionEvent *event = [UARegionEvent regionEventWithRegionID:@"some-id" source:@"some-souurce" boundaryEvent:UABoundaryEventExit];
    NSDate *date = [NSDate now];

    [[self.mockStore expect] save:event eventID:@"neat" eventDate:date sessionID:@"story"];

    [self.eventManager add:event eventID:@"neat" eventDate:date sessionID:@"story"];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertTrue(task.completed);
    XCTAssertEqual(task.initialDelay, 0);

    [self.mockStore verify];
}


/**
 * Test entering background schedules an upload immediately.
 */
- (void)testBackground {
    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertTrue(task.completed);
    XCTAssertEqual(task.initialDelay, 0);
}

/**
 * Test creating a channel schedules an upload.
 */
- (void)testChannelCreated {
    [self.notificationCenter postNotificationName:UAChannel.channelCreatedEvent
                                           object:nil];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];
    XCTAssertTrue(task.completed);
    XCTAssertEqual(task.initialDelay, 15);
}

/**
 * Test uploading events.
 */
- (void)testScheduleUpload {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAEventData *eventData = [self createEventData];
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

    [self.eventManager scheduleUpload];

    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    [self waitForTestExpectations];
    [self.mockClient verify];
    [self.mockStore verify];
    XCTAssertTrue(task.completed);
}

/**
 * Test batch limit.
 */
- (void)testBatchLimit {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    NSMutableArray *events = [NSMutableArray array];
    for (int i = 0; i <= 1000; i++) {
        UAEventData *eventData = [self createEventData];
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

    // Start the upload
    [self.eventManager scheduleUpload];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];


    [self waitForTestExpectations];
    [self.mockClient verify];
    [self.mockStore verify];
    XCTAssertTrue(task.completed);
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
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    // verify
    [self.mockClient verify];
    [self.mockStore verify];
    XCTAssertFalse(task.completed);
}

/**
 * Test failed upload rescheduling an upload.
 */
- (void)testRetryFailedUpload {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    // Set  up a mock event data
    UAEventData *eventData = [self createEventData];
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
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    // Verify
    [self.mockClient verify];
    [self.mockStore verify];
    XCTAssertFalse(task.completed);

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
    [self.eventManager scheduleUpload];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    [self.mockClient verify];
    [self.mockStore verify];
    XCTAssertTrue(task.completed);
}

/**
 * Test batch delay foreground.
 */
- (void)testBatchDelayForeground {
    self.testAppStateTracker.currentState = UAApplicationStateInactive;

    id mockDelay = [self mockForClass:[UADelay class]];
    self.delayProvider = ^(NSTimeInterval delay) {
        XCTAssertEqual(delay, 1);
        return mockDelay;
    };

    [(UADelay *)[mockDelay expect] start];

    // Start the upload
    [self.eventManager scheduleUpload];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    [mockDelay verify];
    XCTAssertTrue(task.completed);
}

/**
 * Test batch delay background.
 */
- (void)testBatchDelayBackground {
    self.testAppStateTracker.currentState = UAApplicationStateBackground;

    id mockDelay = [self mockForClass:[UADelay class]];
    self.delayProvider = ^(NSTimeInterval delay) {
        XCTAssertEqual(delay, 5);
        return mockDelay;
    };

    [(UADelay *)[mockDelay expect] start];

    // Start the upload
    [self.eventManager scheduleUpload];
    UATestTask *task = [self.testTaskManager runEnqueuedRequestsWithTaskID:UAEventManagerUploadTask];

    [mockDelay verify];
}

@end



