/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@interface UABaseTest()
@property (nonatomic, strong) NSPointerArray *mocks;
@end

NSTimeInterval const UATestExpectationTimeOut = 5;

@implementation UABaseTest

- (void)tearDown {
    for (id mock in self.mocks) {
        [mock stopMocking];
    }
    self.mocks = nil;
    [super tearDown];
}

- (id)mockForProtocol:(Protocol *)protocol {
    id mock = OCMProtocolMock(protocol);
    [self addMock:mock];
    return mock;
}

- (id)partialMockForObject:(NSObject *)object {
    id mock = OCMPartialMock(object);
    [self addMock:mock];
    return mock;
}

- (id)strictMockForProtocol:(Protocol *)protocol {
    id mock = OCMStrictProtocolMock(protocol);
    [self addMock:mock];
    return mock;
}

- (id)strictMockForClass:(Class)aClass {
    id mock = OCMStrictClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (id)mockForClass:(Class)aClass {
    id mock = OCMClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (void)addMock:(id)mock {
    if (!self.mocks) {
        self.mocks = [NSPointerArray weakObjectsPointerArray];
    }
    [self.mocks addPointer:(__bridge void *)mock];
}

- (void)waitForTestExpectations:(NSArray<XCTestExpectation *> *)expectations {
    [self waitForExpectations:expectations timeout:UATestExpectationTimeOut];
}

- (void)waitForTestExpectations:(NSArray<XCTestExpectation *> *)expectations enforceOrder:(BOOL)enforceOrder {
    [self waitForExpectations:expectations timeout:UATestExpectationTimeOut enforceOrder:enforceOrder];
}

- (void)waitForTestExpectations {
    [self waitForExpectationsWithTimeout:UATestExpectationTimeOut handler:nil];
}

@end
