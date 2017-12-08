/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAComponent+Internal.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAComponentTests : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id partialMockOfComponent;
@property (nonatomic, strong) UAComponent *component;
@property (nonatomic, assign) BOOL keyExistsInDataStore;
@property (nonatomic, assign) BOOL enabledValueInDataStore;

@end

@implementation UAComponentTests

- (void)setUp {
    [super setUp];
    
    self.enabledValueInDataStore = YES;
    
    // mock the data store
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uacomponent.test."];
    XCTAssertNotNil(self.dataStore);
    [self.dataStore removeAll]; // start with an empty datastore

    // mock uairship to supply our mocked datastore
    self.mockAirship = [self mockForClass:[UAirship class]];
    OCMStub([self.mockAirship shared]).andReturn(self.mockAirship);
    OCMStub([self.mockAirship dataStore]).andReturn(self.dataStore);

    XCTAssertFalse([self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
    self.partialMockOfComponent = OCMPartialMock([[UAComponent alloc] initWithDataStore:self.dataStore]);
    self.component = (UAComponent *)self.partialMockOfComponent;
}

- (void)tearDown {
    [self.dataStore removeAll]; // clear datastore
    
    [super tearDown];
}

- (void)testDefaultEnabled {
    // verify
    XCTAssertTrue(self.component.componentEnabled);
}

- (void)testSetDisabled {
    XCTAssertTrue(self.component.componentEnabled);
    OCMExpect([self.partialMockOfComponent onComponentEnableChange]);

    // test
    self.component.componentEnabled = NO;
    
    // verify
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
    OCMVerifyAll(self.partialMockOfComponent);
}

- (void)testSetDisabledThenEnabled {
    XCTAssertTrue(self.component.componentEnabled);
    OCMExpect([self.partialMockOfComponent onComponentEnableChange]);

    // test
    self.component.componentEnabled = NO;
    
    // verify
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
    OCMVerifyAll(self.partialMockOfComponent);

    // expectations
    OCMExpect([self.partialMockOfComponent onComponentEnableChange]);

    // test
    self.component.componentEnabled = YES;
    
    // verify
    XCTAssertTrue(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
    OCMVerifyAll(self.partialMockOfComponent);
}

- (void)testSetDisabledThenReleaseAndRecreateComponent {
    XCTAssertTrue(self.component.componentEnabled);
    OCMExpect([self.partialMockOfComponent onComponentEnableChange]);

    // test
    self.component.componentEnabled = NO;
    
    // verify
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
    OCMVerifyAll(self.partialMockOfComponent);

    // test
    self.component = [[UAComponent alloc] initWithDataStore:self.dataStore];

    // verify
    XCTAssertFalse(self.component.componentEnabled);
    XCTAssertEqual(self.component.componentEnabled,[self.dataStore boolForKey:@"UAComponent.UAComponent.enabled"]);
}



@end
