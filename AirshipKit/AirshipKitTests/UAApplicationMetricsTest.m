/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestDate.h"

@interface UAApplicationMetricsTest : UABaseTest
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDate *testDate;
@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] init];
    self.testDate.absoluteTime = [NSDate date];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
}

- (void)testApplicationActive {
    XCTAssertNil(self.metrics.lastApplicationOpenDate);

    [self.metrics applicationDidBecomeActive];

    XCTAssertEqualObjects([self.testDate now], self.metrics.lastApplicationOpenDate);

}

@end
