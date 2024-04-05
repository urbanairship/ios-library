/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAAirshipBaseTest.h"
#import "UAFeature.h"

@import AirshipCore;

@interface UAPrivacyManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAPrivacyManagerTest

- (void)setUp {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll resetEnabledFeatures:NO];
}

- (void)testDefaultFeatures {
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone resetEnabledFeatures:NO];
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesNone);
}

- (void)testEnableFeatures {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone resetEnabledFeatures:NO];

    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesNone);
    
    [self.privacyManager enableFeatures:UAFeaturesPush];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesPush);
    
    [self.privacyManager enableFeatures:UAFeaturesContacts];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesPush | UAFeaturesContacts);
}

- (void)testDisableFeatures {
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    [self.privacyManager disableFeatures:UAFeaturesPush];
    
    XCTAssertNotEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    [self.privacyManager disableFeatures:UAFeaturesAnalytics | UAFeaturesMessageCenter | UAFeaturesTagsAndAttributes];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesInAppAutomation | UAFeaturesContacts);
}

- (void)testIsEnabled {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone resetEnabledFeatures:NO];

    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesAnalytics]);
    
    [self.privacyManager enableFeatures:UAFeaturesContacts];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesContacts]);
    
    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesAnalytics]);
    
    [self.privacyManager enableFeatures:UAFeaturesAll];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesInAppAutomation]);
}

- (void)testIsAnyEnabled {
    XCTAssertTrue([self.privacyManager isAnyFeatureEnabled]);
    
    [self.privacyManager disableFeatures:UAFeaturesPush | UAFeaturesContacts];
    
    XCTAssertTrue([self.privacyManager isAnyFeatureEnabled]);
    
    [self.privacyManager disableFeatures:UAFeaturesAll];
    
    XCTAssertFalse([self.privacyManager isAnyFeatureEnabled]);
}

- (void)testSetEnabled {
    self.privacyManager.enabledFeatures = UAFeaturesContacts;

    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesContacts]);
    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesAnalytics]);

    self.privacyManager.enabledFeatures = UAFeaturesAnalytics;
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesAnalytics]);
}

- (void)testNotifiedOnChange {
    __block NSUInteger eventCount = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UAPrivacyManager.changeEvent
                                                                     object:nil
                                                                      queue:nil
                                                                 usingBlock:^(NSNotification * _Nonnull note) {
        eventCount++;
    }];

    self.privacyManager.enabledFeatures = UAFeaturesAll;
    [self.privacyManager disableFeatures:UAFeaturesNone];
    [self.privacyManager enableFeatures:UAFeaturesAll];
    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    XCTAssertEqual(0, eventCount);

    [self.privacyManager disableFeatures:UAFeaturesAnalytics];
    XCTAssertEqual(1, eventCount);

    [self.privacyManager enableFeatures:UAFeaturesAnalytics];
    XCTAssertEqual(2, eventCount);

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

@end
