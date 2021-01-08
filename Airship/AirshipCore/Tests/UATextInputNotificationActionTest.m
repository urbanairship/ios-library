/* Copyright Airship and Contributors */

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

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
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
