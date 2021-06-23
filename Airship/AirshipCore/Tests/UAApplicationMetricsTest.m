/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAApplicationMetrics+Internal.h"
#import "UATestDate.h"

@import AirshipCore;

@interface UAApplicationMetricsTest : UAAirshipBaseTest
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockBundle;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] init];
    self.testDate.absoluteTime = [NSDate date];

    self.notificationCenter = [NSNotificationCenter defaultCenter];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
    self.mockBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:self.mockBundle] mainBundle];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                          privacyManager:self.privacyManager
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
}

- (void)testApplicationActive {
    XCTAssertNil(self.metrics.lastApplicationOpenDate);

    [self.notificationCenter postNotificationName:UAAppStateTracker.didBecomeActiveNotification object:nil];

    XCTAssertEqualObjects([self.testDate now], self.metrics.lastApplicationOpenDate);

}

- (void)testAppVersionUpdated {
    // Fresh install
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"1.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                          privacyManager:self.privacyManager
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];


    XCTAssertFalse(self.metrics.isAppVersionUpdated);


    // Nothing changed
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"1.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                          privacyManager:self.privacyManager
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
    XCTAssertFalse(self.metrics.isAppVersionUpdated);


    // Upgrade
    [[[self.mockBundle expect] andReturn:@{@"CFBundleShortVersionString": @"2.0.0"}] infoDictionary];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.dataStore
                                                          privacyManager:self.privacyManager
                                                      notificationCenter:self.notificationCenter
                                                                    date:self.testDate];
    XCTAssertTrue(self.metrics.isAppVersionUpdated);
}

- (void)testOptedOut {
    [self.notificationCenter postNotificationName:UAAppStateTracker.didBecomeActiveNotification object:nil];
    XCTAssertNotNil(self.metrics.lastApplicationOpenDate);

    [self.privacyManager disableFeatures:UAFeaturesAnalytics];
    XCTAssertNotNil(self.metrics.lastApplicationOpenDate);

    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    [self.privacyManager disableFeatures:UAFeaturesInAppAutomation];
    XCTAssertNotNil(self.metrics.lastApplicationOpenDate);

    [self.privacyManager disableFeatures:UAFeaturesAnalytics];
    [self.privacyManager disableFeatures:UAFeaturesInAppAutomation];
    XCTAssertNil(self.metrics.lastApplicationOpenDate);
}

@end
