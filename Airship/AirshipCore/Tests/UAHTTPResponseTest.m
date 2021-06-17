/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAHTTPResponseTest : UABaseTest

@end

@implementation UAHTTPResponseTest


- (void)testIsSuccess {
    for (int i = 200; i < 300; i++) {
        XCTAssertTrue([[UAHTTPResponse alloc] initWithStatus:i].isSuccess);
    }

    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:300].isSuccess);
    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:199].isSuccess);
}

- (void)testIsClientError {
    for (int i = 400; i < 500; i++) {
        XCTAssertTrue([[UAHTTPResponse alloc] initWithStatus:i].isClientError);
    }

    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:500].isClientError);
    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:399].isClientError);
}

- (void)testIsServerError {
    for (int i = 500; i < 600; i++) {
        XCTAssertTrue([[UAHTTPResponse alloc] initWithStatus:i].isServerError);
    }

    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:600].isServerError);
    XCTAssertFalse([[UAHTTPResponse alloc] initWithStatus:499].isServerError);
}

@end
