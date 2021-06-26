/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
@import AirshipCore;

@interface UAExpirableTaskTest : UABaseTest

@end

@implementation UAExpirableTaskTest

- (void)testExpireNoExpirationHandler {
    __block BOOL completionCalled = NO;
    UAExpirableTask *task = [[UAExpirableTask alloc] initWithTaskID:@"neat" requestOptions:[UATaskRequestOptions defaultOptions] completionHandler:^(BOOL result) {
        XCTAssertFalse(completionCalled);
        completionCalled = YES;

        XCTAssertFalse(result);
    }];

    [task expire];
    XCTAssertTrue(completionCalled);
}

- (void)testExpire {
    __block BOOL completionCalled = NO;
    UAExpirableTask *task = [[UAExpirableTask alloc] initWithTaskID:@"neat" requestOptions:[UATaskRequestOptions defaultOptions] completionHandler:^(BOOL result) {
        XCTAssertFalse(completionCalled);
        completionCalled = YES;
    }];

    __block BOOL expiredCalled = NO;
    task.expirationHandler = ^{
        XCTAssertFalse(expiredCalled);
        expiredCalled = YES;
    };

    [task expire];
    XCTAssertTrue(expiredCalled);
    XCTAssertFalse(completionCalled);
    XCTAssertNil(task.expirationHandler);

    // set it again
    expiredCalled = NO;
    task.expirationHandler = ^{
        XCTAssertFalse(expiredCalled);
        expiredCalled = YES;
    };

    XCTAssertTrue(expiredCalled);
    XCTAssertFalse(completionCalled);
    XCTAssertNil(task.expirationHandler);

    [task taskCompleted];
    XCTAssertTrue(completionCalled);
}

- (void)testCompletionHandler {
    __block BOOL completionCalled = NO;
    UAExpirableTask *task = [[UAExpirableTask alloc] initWithTaskID:@"neat" requestOptions:[UATaskRequestOptions defaultOptions] completionHandler:^(BOOL result) {
        XCTAssertFalse(completionCalled);
        completionCalled = YES;

        XCTAssertTrue(result);
    }];

    task.expirationHandler = ^{
        XCTFail(@"Expiration handler should not be called");
    };

    [task taskCompleted];
    XCTAssertTrue(completionCalled);
    XCTAssertNil(task.expirationHandler);

    // Ignored
    [task taskFailed];
    [task taskCompleted];
    [task expire];
}

@end
