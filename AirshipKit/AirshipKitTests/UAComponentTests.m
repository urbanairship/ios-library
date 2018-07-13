/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAComponent+Internal.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UATestComponent : UAComponent

@property (nonatomic, assign) BOOL onComponentsEnableChangeCalled;
@end

@implementation UATestComponent : UAComponent

- (void)onComponentEnableChange {
    self.onComponentsEnableChangeCalled = YES;
}

@end

@interface UAComponentTests : UABaseTest
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UATestComponent *component;
@end

@implementation UAComponentTests

- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uacomponent.test."];
    [self.dataStore removeAll];

    self.component = [[UATestComponent alloc] initWithDataStore:self.dataStore];
}

- (void)tearDown {
    [self.dataStore removeAll];
    [super tearDown];
}

- (void)testDefaultEnabled {
    XCTAssertTrue(self.component.componentEnabled);
}

- (void)testSetDisabled {
    self.component.componentEnabled = NO;

    XCTAssertTrue(self.component.onComponentsEnableChangeCalled);
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertFalse([self.dataStore boolForKey:@"UAComponent.UATestComponent.enabled"]);
}

- (void)testSetDisabledThenEnabled {
    self.component.componentEnabled = NO;

    XCTAssertTrue(self.component.onComponentsEnableChangeCalled);
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertFalse([self.dataStore boolForKey:@"UAComponent.UATestComponent.enabled"]);

    self.component.onComponentsEnableChangeCalled = NO;
    self.component.componentEnabled = YES;

    XCTAssertTrue(self.component.onComponentsEnableChangeCalled);
    XCTAssertTrue(self.component.componentEnabled);
    XCTAssertTrue([self.dataStore boolForKey:@"UAComponent.UATestComponent.enabled"]);
}

- (void)testSetDisabledThenReleaseAndRecreateComponent {
    // test
    self.component.componentEnabled = NO;

    // test
    self.component = [[UATestComponent alloc] initWithDataStore:self.dataStore];

    // verify
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UATestComponent.enabled"]);
}



@end
