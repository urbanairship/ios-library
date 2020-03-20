/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAEventManager+Internal.h"
#import "UAEventStore+Internal.h"
#import "UAEventAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARuntimeConfig.h"
#import "UACustomEvent.h"
#import "NSOperationQueue+UAAdditions.h"
#import "UARegionEvent.h"
#import "UAAsyncOperation.h"
#import "UAirship+Internal.h"
#import "UAChannel.h"
#import "UAAppStateTracker.h"

/**
 * Test event data class to work around not being able to mock UAEventData
 */
@interface UAEventTestData : NSObject
@property (nullable, nonatomic, copy) NSString *sessionID;
@property (nullable, nonatomic, copy) NSData *data;
@property (nullable, nonatomic, copy) NSString *time;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSString *identifier;
@end

@implementation UAEventTestData
@end

@interface UAEventManagerTest : UABaseTest
@property (nonatomic, strong) UAEventManager *eventManager;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@property (nonatomic, strong) id mockQueue;
@property (nonatomic, strong) id mockClient;
@property (nonatomic, strong) id mockStore;
@property (nonatomic, strong) id mockAppStateTracker;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockDelegate;

@end

@implementation UAEventManagerTest

- (void)setUp {
    [super setUp];

    self.mockClient = [self mockForClass:[UAEventAPIClient class]];
    self.mockStore = [self mockForClass:[UAEventStore class]];
    self.mockQueue = [self mockForClass:[NSOperationQueue class]];

    self.mockChannel = [self mockForClass:[UAChannel class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    // Set up a mocked application
    self.mockAppStateTracker = [self mockForClass:[UAAppStateTracker class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.eventManager = [UAEventManager eventManagerWithConfig:self.config
                                                     dataStore:self.dataStore
                                                       channel:self.mockChannel
                                                    eventStore:self.mockStore
                                                        client:self.mockClient
                                                         queue:self.mockQueue
                                            notificationCenter:self.notificationCenter
                                               appStateTracker:self.mockAppStateTracker];

    self.mockDelegate = [self mockForProtocol:@protocol(UAEventManagerDelegate)];
    self.eventManager.delegate = self.mockDelegate;
}

/*
 * Test deleting all events.
 */
- (void)testDeleteAllEvents {
    [[self.mockClient expect] cancelAllRequests];
    [[self.mockStore expect] deleteAllEvents];

    [self.eventManager deleteAllEvents];

    [self.mockClient verify];
    [self.mockStore verify];
}

/**
 * Test adding an event.
 */
- (void)testAddEvent {
    // setup
    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    // expectations
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async."];

    __block NSTimeInterval delay = -1;
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&delay atIndex:3];
        [expectation fulfill];
        BOOL result = YES;
        [invocation setReturnValue:&result];

    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    // test
    [self.eventManager addEvent:event sessionID:@"story"];

    // verify
    [self waitForTestExpectations];

    [self.mockStore verify];
    [self.mockQueue verify];

    // Verify the delay is somewhere between 10-20 seconds (initial delay 15 - time to run test)
    XCTAssertEqualWithAccuracy(delay, 15, 5);
}

/**
 * Test adding an event when uploads are disabled.
 */
- (void)testAddEventWhenUploadsAreDisabled {
    // setup
    self.eventManager.uploadsEnabled = NO;

    // expectations
    [[[self.mockQueue reject] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    // test
    [self.eventManager addEvent:event sessionID:@"story"];

    // verify
    [self.mockStore verify];
    [self.mockQueue verify];
}

/**
 * Test adding an event in the background defaults to 5 second delay.
 */
- (void)testAddEventBackground {
    // Background application state
    [[[self.mockAppStateTracker stub] andReturnValue:@(UAApplicationStateBackground)] state];

    // expectations
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async."];


    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    __block NSTimeInterval delay = -1;
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&delay atIndex:3];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];

    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    // test
    [self.eventManager addEvent:event sessionID:@"story"];

    // verify
    [self waitForTestExpectations];

    [self.mockStore verify];
    [self.mockQueue verify];

    // Verify the delay is around 5 seconds
    XCTAssertEqualWithAccuracy(delay, 5, .1);
}

/**
 * Test adding an event in the background defaults when uploads are disabled.
 */
- (void)testAddEventBackgroundWhenUploadsAreDisabled {
    // Background application state
    [[[self.mockAppStateTracker stub] andReturnValue:@(UAApplicationStateBackground)] state];
    self.eventManager.uploadsEnabled = NO;

    // expectations
    UACustomEvent *event = [UACustomEvent eventWithName:@"cool"];

    [[[self.mockQueue reject] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    // test
    [self.eventManager addEvent:event sessionID:@"story"];

    // verify
    [self.mockStore verify];
    [self.mockQueue verify];
}

/**
 * Test adding a high priority event defaults to a 1 second delay.
 */
- (void)testAddHighPriorityEvent {
    UARegionEvent *event = [[UARegionEvent alloc] init];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async."];

    __block NSTimeInterval delay = -1;
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&delay atIndex:3];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];

    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


    [[self.mockStore expect] saveEvent:event sessionID:@"story"];

    [self.eventManager addEvent:event sessionID:@"story"];

    [self waitForTestExpectations];

    [self.mockStore verify];
    [self.mockQueue verify];

    // Verify the delay is around 1 seconds
    XCTAssertEqualWithAccuracy(delay, 1, .1);
}

/**
 * Test entering background schedules an upload with a 5 second delay.
 */
- (void)testBackground {

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to happen on main thread."];

    __block NSTimeInterval delay = -1;
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&delay atIndex:3];

        [expectation fulfill];
        BOOL result = YES;
        [invocation setReturnValue:&result];

    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    [self.notificationCenter postNotificationName:UAApplicationDidEnterBackgroundNotification object:nil];

    [self waitForTestExpectations];

    // Verify the delay is around 5 seconds
    XCTAssertEqualWithAccuracy(delay, 5, .1);
}

/**
 * Test entering background does not schedule an upload when uploads are disabled.
 */
- (void)testBackgroundWhenUploadsAreDisabled {
    // setup
    self.eventManager.uploadsEnabled = NO;

    // expectations
    [[[self.mockQueue reject] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    [self.notificationCenter postNotificationName:UAApplicationDidEnterBackgroundNotification
                                           object:nil];

    [self.mockQueue verify];
}

/**
 * Test creating a channel schedules an upload.
 */
- (void)testChannelCreated {
    __block NSTimeInterval delay = -1;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async."];

    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&delay atIndex:3];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];

    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                           object:nil];

    [self waitForTestExpectations];

    // Verify the delay is around 15 seconds
    XCTAssertEqualWithAccuracy(delay, 15, 5);
}

/**
 * Test scheduling an upload with an earlier time will cancel the current operations.
 */
- (void)testRescheduleUpload {
    // Add a normal priority event (delay 15ish seconds)
    [self testAddEvent];

    // Make sure it cancels the previous attempt
    [[self.mockQueue expect] cancelAllOperations];

    // Add a high priority event (delay 5ish seconds)
    [self testAddHighPriorityEvent];

    [self.mockQueue verify];
}

/**
 * Test uploading events.
 */
- (void)testScheduleUpload {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async"];

    // Run the operation as when added
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        // Start the operation
        __weak NSOperation *operation = nil;
        [invocation getArgument:&operation atIndex:2];
        [operation start];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


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
    }] ignoringNonObjectArgs] fetchEventsWithMaxBatchSize:0 completionHandler:OCMOCK_ANY];

    NSDictionary *headers = @{@"header": @"headerValue"};
    [[[self.mockDelegate stub] andReturn:headers] analyticsHeaders];

    XCTestExpectation *clientCalled = [self expectationWithDescription:@"client upload callled."];
    // Expect a call to the client, return a 200 response
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^returnBlock)(NSHTTPURLResponse *response)= (__bridge void (^)(NSHTTPURLResponse *))arg;

        // Return a success response
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        returnBlock(response);
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

    // Start the upload
    [self.eventManager scheduleUpload];

    [self waitForTestExpectations];

    [self.mockQueue verify];
    [self.mockClient verify];
    [self.mockStore verify];
}

/**
 * Test uploading events when uploads are disabled.
 */
- (void)testScheduleUploadWhenUploadsAreDisabled {
    // setup
    self.eventManager.uploadsEnabled = NO;

    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    // expectations
    // Run the operation as when added
    [[[self.mockQueue reject] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    // Reject any calls to the store
    [[[self.mockStore reject] ignoringNonObjectArgs] fetchEventsWithMaxBatchSize:0 completionHandler:OCMOCK_ANY];

    // Reject any calls to the client
    [[self.mockClient reject] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // test
    [self.eventManager scheduleUpload];

    // verify
    [self.mockQueue verify];
    [self.mockClient verify];
    [self.mockStore verify];
}

/**
 * Test failed upload rescheduling an upload.
 */
- (void)testRetryFailedUpload {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async."];

    // Initial request
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        // Start the operation
        __weak NSOperation *operation = nil;
        [invocation getArgument:&operation atIndex:2];
        [operation start];

        BOOL result = YES;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


    // Retry request
    __block NSTimeInterval retryDelay = -1;
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [invocation getArgument:&retryDelay atIndex:3];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


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
    }] ignoringNonObjectArgs] fetchEventsWithMaxBatchSize:0 completionHandler:OCMOCK_ANY];


    // Expect a call to the client, return a 200 response
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^returnBlock)(NSHTTPURLResponse *response)= (__bridge void (^)(NSHTTPURLResponse *))arg;

        // Return a 400 response
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        returnBlock(response);
    }] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Expect the store to delete the event
    [[self.mockStore reject] deleteEventsWithIDs:OCMOCK_ANY];

    // Start the upload
    [self.eventManager scheduleUpload];

    [self waitForTestExpectations];

    // Verify the delay is around 60 seconds
    XCTAssertEqualWithAccuracy(retryDelay, 60, .1);

    [self.mockQueue verify];
    [self.mockClient verify];
    [self.mockStore verify];
}

/**
 * Test uploading no-ops if the channel is not available.
 */
- (void)testUploadNoChannel {
    // Set a channel ID
    [[[self.mockChannel stub] andReturn:nil] identifier];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async"];


    // Run the operation as when added
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        // Start the operation
        __weak NSOperation *operation = nil;
        [invocation getArgument:&operation atIndex:2];
        [operation start];

        [expectation fulfill];

        BOOL result = YES;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];


    // Reject store and client calls
    [[[self.mockStore reject] ignoringNonObjectArgs] fetchEventsWithMaxBatchSize:0 completionHandler:OCMOCK_ANY];
    [[self.mockClient reject] uploadEvents:OCMOCK_ANY headers:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Start the upload
    [self.eventManager scheduleUpload];

    [self waitForTestExpectations];

    [self.mockQueue verify];
    [self.mockClient verify];
    [self.mockStore verify];
}

- (void)testEnableSchedulesUploadWhenCurrentlyDisabled {
    // setup
    self.eventManager.uploadsEnabled = NO;

    // expectations
    XCTestExpectation *expectUpload = [self expectationWithDescription:@"Expect upload via [self.queue addBackgroundOperation:delay:]"];
    [[[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [expectUpload fulfill];
    }] ignoringNonObjectArgs] addBackgroundOperation:OCMOCK_ANY delay:0];

    // test
    self.eventManager.uploadsEnabled = YES;

    // verify
    [self waitForTestExpectations];
    [self.mockQueue verify];
}

- (void)testDisableCancelsUploadsWhenCurrentlyEnabled {
    // setup
    self.eventManager.uploadsEnabled = YES;

    // expectations
    XCTestExpectation *expectCancel = [self expectationWithDescription:@"Expect cancel via [self.queue addBackgroundOperation:delay:]"];
    [[[self.mockQueue expect] andDo:^(NSInvocation *invocation) {
        [expectCancel fulfill];
    }] cancelAllOperations];

    // test
    self.eventManager.uploadsEnabled = NO;

    // verify
    [self waitForTestExpectations];
    [self.mockQueue verify];
}

@end


