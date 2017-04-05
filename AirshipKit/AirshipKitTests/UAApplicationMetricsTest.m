/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import <OCMock/OCMock.h>

@interface UAApplicationMetricsTest : XCTestCase
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) id mockDataStore;
@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.mockDataStore];
}

- (void)tearDown {
    [super tearDown];

    [self.mockDataStore stopMocking];
}

- (void)testApplicationActive {
    // Make date always return our expected date
    NSDate *expectedDate = [NSDate date];
    id mockDate = [OCMockObject mockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:expectedDate] date];

    [[self.mockDataStore expect] setObject:expectedDate forKey:@"UAApplicationMetricLastOpenDate"];

    [self.metrics didBecomeActive];

    [self.mockDataStore verify];

    [mockDate stopMocking];
}

@end
