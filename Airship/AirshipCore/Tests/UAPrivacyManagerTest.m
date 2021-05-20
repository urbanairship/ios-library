/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAAirshipBaseTest.h"
#import "UAPrivacyManager+Internal.h"

@interface UAPrivacyManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAPrivacyManagerTest

- (void)setUp {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
}

- (void)testDefaultFeatures {
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesNone);
}

- (void)testEnableFeatures {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesNone);
    
    [self.privacyManager enableFeatures:UAFeaturesPush];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesPush);
    
    [self.privacyManager enableFeatures:UAFeaturesContacts];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesPush | UAFeaturesContacts);
    
    [self.privacyManager enableFeatures:UAFeaturesLocation | UAFeaturesAnalytics];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesPush | UAFeaturesContacts | UAFeaturesAnalytics | UAFeaturesLocation);
    
    XCTAssertNotEqual(self.privacyManager.enabledFeatures, UAFeaturesChat);
}

- (void)testDisableFeatures {
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    [self.privacyManager disableFeatures:UAFeaturesPush];
    
    XCTAssertNotEqual(self.privacyManager.enabledFeatures, UAFeaturesAll);
    
    [self.privacyManager disableFeatures:UAFeaturesLocation | UAFeaturesAnalytics | UAFeaturesMessageCenter | UAFeaturesTagsAndAttributes];
    
    XCTAssertEqual(self.privacyManager.enabledFeatures, UAFeaturesChat | UAFeaturesInAppAutomation | UAFeaturesContacts);
}

- (void)testIsEnabled {
    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesNone];
    
    XCTAssertFalse([self.privacyManager isEnabled:UAFeaturesChat]);
    
    [self.privacyManager enableFeatures:UAFeaturesContacts];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesContacts]);
    
    [self.privacyManager enableFeatures:UAFeaturesChat];
    
    XCTAssertTrue([self.privacyManager isEnabled:UAFeaturesChat]);
    
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

@end
