/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface UABaseTest : XCTestCase

- (id)mockForClass:(Class)aClass;
- (id)strictMockForClass:(Class)aClass;

- (id)mockForProtocol:(Protocol *)protocol;

- (id)partialMockForObject:(NSObject *)object;


@end
