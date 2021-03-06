/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAModifyAttributesAction.h"
#import "UAAction+Operators.h"
#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "UAChannel+Internal.h"
#import "UANamedUser+Internal.h"

@interface UAModifyAttributesActionTest : UABaseTest

@property (nonatomic, assign) id mockAirship;
@property (nonatomic, assign) id mockChannel;
@property (nonatomic, assign) id mockNamedUser;
@property (nonatomic, strong) UAActionArguments *arguments;

@end


@implementation UAModifyAttributesActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];
    [[[self.mockAirship stub] andReturn:self.mockNamedUser] namedUser];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockChannel stopMocking];
    [self.mockNamedUser stopMocking];
    [super tearDown];
}

/**
 * Test that the action accepts valid arguments.
 */
- (void)testAcceptsArguments {
    UAAction *action = [[UAModifyAttributesAction alloc] init];

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
    XCTAssertTrue([action acceptsArguments:self.arguments], @"Action should accept a valid JSON");

    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:self.arguments], @"Action should not accept arguments with UASituationBackgroundPush situation");
    
    self.arguments.situation = UASituationManualInvocation;
    XCTAssertTrue([action acceptsArguments:self.arguments], @"Action should accept any situations that is not UASituationBackgroundPush");
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive"},
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    self.arguments.value = @{
        @"named_user": @{
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive"},
        },
        @"named_user": @{
                @"remove": @[@"zipcode"]
        }
    };
    XCTAssertTrue([action acceptsArguments:self.arguments], @"Action should accept a valid JSON");
   
    
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
    XCTAssertFalse([action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON");
    
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
    XCTAssertFalse([action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON - a dictionary is expected");
    

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
    XCTAssertFalse([action acceptsArguments:self.arguments], @"Action shouldn't accept an invalid JSON - an array is expected");
    
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

    UAAction *action = [[UAModifyAttributesAction alloc] init];

    [[self.mockChannel expect] applyAttributeMutations:OCMOCK_ANY];
    [[self.mockNamedUser expect] applyAttributeMutations:OCMOCK_ANY];
    
    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];
    
    [self.mockChannel verify];
    [self.mockNamedUser verify];
}
 
/**
 * Test perform with channel attributes.
 */
- (void)testPerformWithArgumentsExpectChannel {
    self.arguments.situation = UASituationManualInvocation;

    UAAction *action = [[UAModifyAttributesAction alloc] init];
    
    self.arguments.value = @{
        @"channel": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        }
    };
    
    [[self.mockChannel expect] applyAttributeMutations:OCMOCK_ANY];
    [[self.mockNamedUser reject] applyAttributeMutations:OCMOCK_ANY];
    
    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];
    
    [self.mockChannel verify];
    [self.mockNamedUser verify];
}

/**
 * Test perform with named user attributes.
 */
- (void)testPerformWithArgumentsExpectNamedUser {
    self.arguments.situation = UASituationManualInvocation;

    UAAction *action = [[UAModifyAttributesAction alloc] init];
    
    self.arguments.value = @{
        @"named_user": @{
                @"set": @{@"name": @"clive", @"age": @16, @"birth_date": [NSDate date]},
                @"remove": @[@"zipcode"]
        }
    };
    
    [[self.mockChannel reject] applyAttributeMutations:OCMOCK_ANY];
    [[self.mockNamedUser expect] applyAttributeMutations:OCMOCK_ANY];
    
    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNil(performResult.value);
        XCTAssertNil(performResult.error);
    }];
    
    [self.mockChannel verify];
    [self.mockNamedUser verify];
}

@end
