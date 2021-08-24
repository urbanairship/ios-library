/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAComponent.h"
#import "UAirship+Internal.h"

@import AirshipCore;

@interface UATestComponent : UAComponent

@property (nonatomic, assign) BOOL onComponentsEnableChangeCalled;
@end

@implementation UATestComponent : UAComponent

- (void)onComponentEnableChange {
    self.onComponentsEnableChangeCalled = YES;
}

@end

@interface UAComponentTests : UAAirshipBaseTest
@property (nonatomic, strong) UATestComponent *component;
@end

@implementation UAComponentTests

- (void)setUp {
    [super setUp];

    self.component = [[UATestComponent alloc] initWithDataStore:self.dataStore];
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
