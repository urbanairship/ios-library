/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UATextInputNotificationAction.h"

static NSString *kTestIdentifier = @"TESTID";
static NSString *kTestTitle = @"kTestTitle";
static NSString *kTestTextInputButtonTitle = @"kTestTextInputButtonTitle";
static NSString *kTestTextInputPlaceholder = @"kTestTextInputPlaceholder";
static NSString *kTestIdentifier2  = @"TESTID2";

@interface UATextInputNotificationActionTest : UABaseTest

@end

@implementation UATextInputNotificationActionTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void)testAsUIUserNotificationActionBackground {

    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionNone];
    UIUserNotificationAction *convertedToUIUserNotificationAction = [uaTextInputNotificationAction asUIUserNotificationAction];

    UIMutableUserNotificationAction *uiUserNotificationAction = [[UIMutableUserNotificationAction alloc] init];
    uiUserNotificationAction.identifier = kTestIdentifier;
    uiUserNotificationAction.title = kTestTitle;
    uiUserNotificationAction.behavior = UIUserNotificationActionBehaviorTextInput;
    uiUserNotificationAction.parameters = @{UIUserNotificationTextInputActionButtonTitleKey:kTestTextInputButtonTitle};
    uiUserNotificationAction.activationMode = UIUserNotificationActivationModeBackground;
    
    // check isEqual
    XCTAssertTrue([uaTextInputNotificationAction isEqualToUIUserNotificationAction:uiUserNotificationAction]);
    
    // manually check each property
    XCTAssertTrue([convertedToUIUserNotificationAction.identifier isEqual:uiUserNotificationAction.identifier]);
    XCTAssertTrue([convertedToUIUserNotificationAction.title isEqual:uiUserNotificationAction.title]);
    XCTAssertTrue(convertedToUIUserNotificationAction.behavior == uiUserNotificationAction.behavior);
    XCTAssertTrue([convertedToUIUserNotificationAction.parameters isEqual:uiUserNotificationAction.parameters]);
    XCTAssertTrue(convertedToUIUserNotificationAction.activationMode == uiUserNotificationAction.activationMode);
    XCTAssertTrue(convertedToUIUserNotificationAction.authenticationRequired == uiUserNotificationAction.authenticationRequired);
    XCTAssertTrue(convertedToUIUserNotificationAction.destructive == uiUserNotificationAction.destructive);
}

- (void)testAsUIUserNotificationActionForeground {
    
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionForeground];
    UIUserNotificationAction *convertedToUIUserNotificationAction = [uaTextInputNotificationAction asUIUserNotificationAction];
    
    UIMutableUserNotificationAction *uiUserNotificationAction = [[UIMutableUserNotificationAction alloc] init];
    uiUserNotificationAction.identifier = kTestIdentifier;
    uiUserNotificationAction.title = kTestTitle;
    uiUserNotificationAction.behavior = UIUserNotificationActionBehaviorTextInput;
    uiUserNotificationAction.parameters = @{UIUserNotificationTextInputActionButtonTitleKey:kTestTextInputButtonTitle};
    uiUserNotificationAction.activationMode = UIUserNotificationActivationModeForeground;
    
    // check isEqual
    XCTAssertTrue([uaTextInputNotificationAction isEqualToUIUserNotificationAction:uiUserNotificationAction]);
    
    // manually check each property
    XCTAssertTrue([convertedToUIUserNotificationAction.identifier isEqual:uiUserNotificationAction.identifier]);
    XCTAssertTrue([convertedToUIUserNotificationAction.title isEqual:uiUserNotificationAction.title]);
    XCTAssertTrue(convertedToUIUserNotificationAction.behavior == uiUserNotificationAction.behavior);
    XCTAssertTrue([convertedToUIUserNotificationAction.parameters isEqual:uiUserNotificationAction.parameters]);
    // asUIUserNotificationAction forces background because of an iOS9 bug
    XCTAssertTrue(convertedToUIUserNotificationAction.activationMode != uiUserNotificationAction.activationMode);
    XCTAssertTrue(convertedToUIUserNotificationAction.activationMode == UIUserNotificationActivationModeBackground);
    XCTAssertTrue(uiUserNotificationAction.activationMode == UIUserNotificationActivationModeForeground);
    XCTAssertTrue(convertedToUIUserNotificationAction.authenticationRequired == uiUserNotificationAction.authenticationRequired);
    XCTAssertTrue(convertedToUIUserNotificationAction.destructive == uiUserNotificationAction.destructive);
}

- (void)testAsUIUserNotificationActionForegroundOverrideForceBackground {
    
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionForeground];
    uaTextInputNotificationAction.forceBackgroundActivationModeInIOS9 = NO;
    UIUserNotificationAction *convertedToUIUserNotificationAction = [uaTextInputNotificationAction asUIUserNotificationAction];
    
    UIMutableUserNotificationAction *uiUserNotificationAction = [[UIMutableUserNotificationAction alloc] init];
    uiUserNotificationAction.identifier = kTestIdentifier;
    uiUserNotificationAction.title = kTestTitle;
    uiUserNotificationAction.behavior = UIUserNotificationActionBehaviorTextInput;
    uiUserNotificationAction.parameters = @{UIUserNotificationTextInputActionButtonTitleKey:kTestTextInputButtonTitle};
    uiUserNotificationAction.activationMode = UIUserNotificationActivationModeForeground;

    // check isEqual
    XCTAssertTrue([uaTextInputNotificationAction isEqualToUIUserNotificationAction:uiUserNotificationAction]);

    // manually check each property
    XCTAssertTrue([convertedToUIUserNotificationAction.identifier isEqual:uiUserNotificationAction.identifier]);
    XCTAssertTrue([convertedToUIUserNotificationAction.title isEqual:uiUserNotificationAction.title]);
    XCTAssertTrue(convertedToUIUserNotificationAction.behavior == uiUserNotificationAction.behavior);
    XCTAssertTrue([convertedToUIUserNotificationAction.parameters isEqual:uiUserNotificationAction.parameters]);
    // asUIUserNotificationAction forces background because of an iOS9 bug
    XCTAssertTrue(convertedToUIUserNotificationAction.activationMode == uiUserNotificationAction.activationMode);
    XCTAssertTrue(convertedToUIUserNotificationAction.authenticationRequired == uiUserNotificationAction.authenticationRequired);
    XCTAssertTrue(convertedToUIUserNotificationAction.destructive == uiUserNotificationAction.destructive);
}

- (void)testAsUIUserNotificationActionBackgroundNotEqual {
    
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionNone];
    UIUserNotificationAction *convertedToUIUserNotificationAction = [uaTextInputNotificationAction asUIUserNotificationAction];
    
    UIMutableUserNotificationAction *uiUserNotificationAction = [[UIMutableUserNotificationAction alloc] init];
    uiUserNotificationAction.identifier = kTestIdentifier2;
    uiUserNotificationAction.title = kTestTitle;
    uiUserNotificationAction.behavior = UIUserNotificationActionBehaviorTextInput;
    uiUserNotificationAction.parameters = @{UIUserNotificationTextInputActionButtonTitleKey:kTestTextInputButtonTitle};
    uiUserNotificationAction.activationMode = UIUserNotificationActivationModeBackground;
    
    // check isEqual
    XCTAssertFalse([uaTextInputNotificationAction isEqualToUIUserNotificationAction:uiUserNotificationAction]);
    
    // manually check each property
    XCTAssertFalse([convertedToUIUserNotificationAction.identifier isEqual:uiUserNotificationAction.identifier]);
    XCTAssertTrue([convertedToUIUserNotificationAction.title isEqual:uiUserNotificationAction.title]);
    XCTAssertTrue(convertedToUIUserNotificationAction.behavior == uiUserNotificationAction.behavior);
    XCTAssertTrue([convertedToUIUserNotificationAction.parameters isEqual:uiUserNotificationAction.parameters]);
    XCTAssertTrue(convertedToUIUserNotificationAction.activationMode == uiUserNotificationAction.activationMode);
    XCTAssertTrue(convertedToUIUserNotificationAction.authenticationRequired == uiUserNotificationAction.authenticationRequired);
    XCTAssertTrue(convertedToUIUserNotificationAction.destructive == uiUserNotificationAction.destructive);
}

- (void)testAsUNNotificationActionBackground {
    
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionNone];
    UNNotificationAction *convertedToUNNotificationAction = [uaTextInputNotificationAction asUNNotificationAction];
    XCTAssertTrue([convertedToUNNotificationAction isKindOfClass:[UNTextInputNotificationAction class]]);
    UNTextInputNotificationAction *convertedToUNTextInputNotificationAction = (UNTextInputNotificationAction *)convertedToUNNotificationAction;
    
    UNTextInputNotificationAction *unTextInputNotificationAction = [UNTextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle options:UNNotificationActionOptionNone textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder];
    
    // check isEqual
    XCTAssertTrue([uaTextInputNotificationAction isEqualToUNNotificationAction:unTextInputNotificationAction]);
    
    // manually check each property
    XCTAssertTrue([convertedToUNTextInputNotificationAction.identifier isEqual:unTextInputNotificationAction.identifier]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.title isEqual:unTextInputNotificationAction.title]);
    XCTAssertTrue(convertedToUNTextInputNotificationAction.options == unTextInputNotificationAction.options);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputButtonTitle isEqual:unTextInputNotificationAction.textInputButtonTitle]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputPlaceholder isEqual:unTextInputNotificationAction.textInputPlaceholder]);
}

- (void)testAsUNNotificationActionForeground {
    
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionForeground];
    UNNotificationAction *convertedToUNNotificationAction = [uaTextInputNotificationAction asUNNotificationAction];
    XCTAssertTrue([convertedToUNNotificationAction isKindOfClass:[UNTextInputNotificationAction class]]);
    UNTextInputNotificationAction *convertedToUNTextInputNotificationAction = (UNTextInputNotificationAction *)convertedToUNNotificationAction;
    
    UNTextInputNotificationAction *unTextInputNotificationAction = [UNTextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle options:UNNotificationActionOptionForeground textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder];
    
    // check isEqual
    XCTAssertTrue([uaTextInputNotificationAction isEqualToUNNotificationAction:unTextInputNotificationAction]);
    
    // manually check each property
    XCTAssertTrue([convertedToUNTextInputNotificationAction.identifier isEqual:unTextInputNotificationAction.identifier]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.title isEqual:unTextInputNotificationAction.title]);
    XCTAssertTrue(convertedToUNTextInputNotificationAction.options == unTextInputNotificationAction.options);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputButtonTitle isEqual:unTextInputNotificationAction.textInputButtonTitle]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputPlaceholder isEqual:unTextInputNotificationAction.textInputPlaceholder]);
}

- (void)testAsUNNotificationActionForegroundNotEqual {
    UATextInputNotificationAction *uaTextInputNotificationAction = [UATextInputNotificationAction actionWithIdentifier:kTestIdentifier title:kTestTitle textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder options:UANotificationActionOptionForeground];
    UNNotificationAction *convertedToUNNotificationAction = [uaTextInputNotificationAction asUNNotificationAction];
    XCTAssertTrue([convertedToUNNotificationAction isKindOfClass:[UNTextInputNotificationAction class]]);
    UNTextInputNotificationAction *convertedToUNTextInputNotificationAction = (UNTextInputNotificationAction *)convertedToUNNotificationAction;
    
    UNTextInputNotificationAction *unTextInputNotificationAction = [UNTextInputNotificationAction actionWithIdentifier:kTestIdentifier2 title:kTestTitle options:UNNotificationActionOptionForeground textInputButtonTitle:kTestTextInputButtonTitle textInputPlaceholder:kTestTextInputPlaceholder];
    
    // check isEqual
    XCTAssertFalse([uaTextInputNotificationAction isEqualToUNNotificationAction:unTextInputNotificationAction]);
    
    // manually check each property
    XCTAssertFalse([convertedToUNTextInputNotificationAction.identifier isEqual:unTextInputNotificationAction.identifier]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.title isEqual:unTextInputNotificationAction.title]);
    XCTAssertTrue(convertedToUNTextInputNotificationAction.options == unTextInputNotificationAction.options);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputButtonTitle isEqual:unTextInputNotificationAction.textInputButtonTitle]);
    XCTAssertTrue([convertedToUNTextInputNotificationAction.textInputPlaceholder isEqual:unTextInputNotificationAction.textInputPlaceholder]);
}
#pragma GCC diagnostic pop

@end
