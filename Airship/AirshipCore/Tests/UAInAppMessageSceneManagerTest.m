/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageSceneManager+Internal.h"

@interface UAInAppMessageSceneManagerTest : UABaseTest
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAInAppMessageSceneManager *sceneManager;
@property (nonatomic, strong) id mockWindowScene;
@property (nonatomic, strong) id mockAlternateWindowScene;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockMessage;
@end

/**
 * UAInAppMessageSceneManager tests.
 */
@implementation UAInAppMessageSceneManagerTest

- (void)setUp {
    [super setUp];

    // UIScene is only on iOS 13 and above
    if (@available(iOS 13.0, *)) {
        self.mockWindowScene = [self mockForClass:[UIWindowScene class]];
        self.mockAlternateWindowScene = [self mockForClass:[UIWindowScene class]];

        self.mockMessage = [self mockForClass:[UAInAppMessage class]];

        self.mockDelegate = [self mockForProtocol:@protocol(UAInAppMessageSceneDelegate)];
        self.notificationCenter = [[NSNotificationCenter alloc] init];

        self.sceneManager = [UAInAppMessageSceneManager managerWithNotificationCenter:self.notificationCenter];
    }
}

- (void)testSceneForMessage {
    // UIScene is only on iOS 13 and above
    if (@available(iOS 13.0, *)) {
        [self.notificationCenter postNotificationName:UISceneWillConnectNotification object:self.mockWindowScene];
        XCTAssertEqual(self.mockWindowScene, [self.sceneManager sceneForMessage:self.mockMessage]);

        [self.notificationCenter postNotificationName:UISceneWillConnectNotification object:self.mockAlternateWindowScene];
        XCTAssertEqual(self.mockAlternateWindowScene, [self.sceneManager sceneForMessage:self.mockMessage]);

        [self.notificationCenter postNotificationName:UISceneDidDisconnectNotification object:self.mockAlternateWindowScene];
        XCTAssertEqual(self.mockWindowScene, [self.sceneManager sceneForMessage:self.mockMessage]);

        [self.notificationCenter postNotificationName:UISceneDidDisconnectNotification object:self.mockWindowScene];
        XCTAssertNil([self.sceneManager sceneForMessage:self.mockMessage]);
    }
}

- (void)testSceneForMessageNoScenes {
    // UIScene is only on iOS 13 and above
    if (@available(iOS 13.0, *)) {
        XCTAssertNil([self.sceneManager sceneForMessage:self.mockMessage]);
    }
}

- (void)testSceneForMessageOverride {
    // UIScene is only on iOS 13 and above
    if (@available(iOS 13.0, *)) {
        [self.notificationCenter postNotificationName:UISceneWillConnectNotification object:self.mockWindowScene];
        [[[self.mockDelegate stub] andReturn:self.mockAlternateWindowScene] sceneForMessage:self.mockMessage defaultScene:self.mockWindowScene];
        self.sceneManager.delegate = self.mockDelegate;

        XCTAssertEqual(self.mockAlternateWindowScene, [self.sceneManager sceneForMessage:self.mockMessage]);
    }
}

@end
