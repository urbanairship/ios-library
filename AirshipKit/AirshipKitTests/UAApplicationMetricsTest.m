/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAApplicationMetricsTest : UABaseTest
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) id mockDataStore;
@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.mockDataStore = [self mockForClass:[UAPreferenceDataStore class]];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.mockDataStore];
}

- (void)tearDown {
    [self.mockDataStore stopMocking];
    [super tearDown];
}

- (void)testApplicationActive {
    // Make date always return our expected date
    NSDate *expectedDate = [NSDate date];
    id mockDate = [self strictMockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:expectedDate] date];

    [[self.mockDataStore expect] setObject:expectedDate forKey:@"UAApplicationMetricLastOpenDate"];

    [self.metrics didBecomeActive];

    [self.mockDataStore verify];

    [mockDate stopMocking];
}

@end
