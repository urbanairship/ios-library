/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAScheduleDeferredData+Internal.h"

@interface UAScheduleDeferredDataTest : UABaseTest

@end

@implementation UAScheduleDeferredDataTest

- (void)testFromJSON {
    id JSON = @{ @"url": @"https://neat.com", @"retry_on_timeout": @(NO) };

    NSError *error;

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:JSON error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://neat.com"], deferred.URL);
    XCTAssertFalse(deferred.retriableOnTimeout);
    XCTAssertEqual(UAScheduleDataDeferredTypeUnknown, deferred.type);
}

- (void)testFromJSONWithType {
    id JSON = @{ @"url": @"https://neat.com", @"retry_on_timeout": @(NO), @"type": @"in_app_message"};

    NSError *error;

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:JSON error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://neat.com"], deferred.URL);
    XCTAssertFalse(deferred.retriableOnTimeout);
    XCTAssertEqual(UAScheduleDataDeferredTypeInAppMessage, deferred.type);
}

- (void)testFromJSONDefaultTimeout {
    id JSON = @{ @"url": @"https://neat.com" };

    NSError *error;

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:JSON error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://neat.com"], deferred.URL);
    XCTAssertTrue(deferred.retriableOnTimeout);
}

- (void)testFromJSONMissingURL {
    id JSON = @{ @"retry_on_timeout": @(NO) };

    NSError *error;

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithJSON:JSON error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(deferred);

}

- (void)testToJSON {
    id expectedJSON = @{ @"url": @"https://neat.com", @"retry_on_timeout": @(YES), @"type": @"in_app_message" };

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://neat.com"]
                                                                retriableOnTimeout:YES
                                                                              type:UAScheduleDataDeferredTypeInAppMessage];

    id toJSON = [deferred toJSON];
    XCTAssertEqualObjects(expectedJSON, toJSON);
}

@end
