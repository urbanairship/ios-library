/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionArguments+Internal.h"
#import "UAActionResult.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAModifyAttributesActionTest : UABaseTest

@property (nonatomic, strong) UATestChannel *testChannel;
@property (nonatomic, strong) UATestContact *testContact;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) UAModifyAttributesAction *action;

@end


@implementation UAModifyAttributesActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    
    self.testChannel = [[UATestChannel alloc] init];
    self.testContact = [[UATestContact alloc] init];
    self.action = [[UAModifyAttributesAction alloc] initWithChannel:^{ return self.testChannel; }
                                                            contact:^{ return self.testContact; }];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test that the action accepts valid arguments.
 */
- (void)testAcceptsArguments {
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        },
        @"named_user": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Action should accept a valid JSON");

    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Action should not accept arguments with UASituationBackgroundPush situation");
    
    self.arguments.situation = UASituationManualInvocation;
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Action should accept any situations that is not UASituationBackgroundPush");
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    self.arguments.value = @{
        @"named_user": @{
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive"},
        },
        @"named_user": @{
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    
    self.arguments.value = @{
        @"chanel": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        },
        @"nameduser": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON");
    
    self.arguments.value = @{
        @"channel": @{
                @"set":  @[@"zipcode"],
                @"remove": @[@"zipcode"]
        },
        @"named_user": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON - a dictionary is expected");
    

    self.arguments.value = @{
        @"channel": @{
                @"set":  @{@"name": @"clive"},
                @"remove": @{@"name": @"clive"}
        },
        @"named_user": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON - an array is expected");
    
}

/**
 * Test perform with both channel and named user attributes..
 */
- (void)testPerformWithArgumentsExpectBoth {

    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        },
        @"named_user": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        }
    };
    self.arguments.situation = UASituationManualInvocation;

    XCTestExpectation *contactEdited = [self expectationWithDescription:@"contact edited"];
    self.testContact.attributeEditor = [[UAAttributesEditor alloc] initWithCompletionHandler:^(NSArray<UAAttributeUpdate *> *updates) {
        [contactEdited fulfill];
    }];

    XCTestExpectation *channelEdited = [self expectationWithDescription:@"channel edited"];
    self.testChannel.attributeEditor = [[UAAttributesEditor alloc] initWithCompletionHandler:^(NSArray<UAAttributeUpdate *> *updates) {
        [channelEdited fulfill];
    }];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];
    
    [self waitForTestExpectations];
}
 
/**
 * Test perform with channel attributes.
 */
- (void)testPerformWithArgumentsExpectChannel {
    self.arguments.situation = UASituationManualInvocation;
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        }
    };

    XCTestExpectation *channelEdited = [self expectationWithDescription:@"channel edited"];
    self.testChannel.attributeEditor = [[UAAttributesEditor alloc] initWithCompletionHandler:^(NSArray<UAAttributeUpdate *> *updates) {
        [channelEdited fulfill];
    }];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];

    [self waitForTestExpectations];
}

/**
 * Test perform with named user attributes.
 */
- (void)testPerformWithArgumentsExpectNamedUser {
    self.arguments.situation = UASituationManualInvocation;
    
    self.arguments.value = @{
        @"named_user": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        }
    };
    
    XCTestExpectation *contactEdited = [self expectationWithDescription:@"contact edited"];
    self.testContact.attributeEditor = [[UAAttributesEditor alloc] initWithCompletionHandler:^(NSArray<UAAttributeUpdate *> *updates) {
        [contactEdited fulfill];
    }];

    [self.action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];
    
    [self waitForTestExpectations];
}

@end
