/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestDate.h"
#import "UAAppStateTracker.h"

@interface UAApplicationMetricsTest : UAAirshipBaseTest
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockBundle;

@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] init];
    self.testDate.absoluteTime = [NSDate date];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.mockBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:self.mockBundle] mainBundle];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
}

- (void)testApplicationActive {
    XCTAssertNil(self.metrics.lastApplicationOpenDate);

    [self.notificationCenter postNotificationName:UAApplicationDidBecomeActiveNotification object:nil];

    XCTAssertEqualObjects([self.testDate now], self.metrics.lastApplicationOpenDate);

}

- (void)testAppVersionUpdated {
    // Fresh install
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"1.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];


    XCTAssertFalse(self.metrics.isAppVersionUpdated);


    // Nothing changed
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"1.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
    XCTAssertFalse(self.metrics.isAppVersionUpdated);


    // Upgrade
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"2.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
    XCTAssertTrue(self.metrics.isAppVersionUpdated);
}

@end
