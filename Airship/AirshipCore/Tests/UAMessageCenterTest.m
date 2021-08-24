/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenter+Internal.h"
#import "UAUser.h"
#import "UAInboxMessageList.h"
#import "UAComponent.h"

@import AirshipCore;

@interface UAMessageCenterTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockDefaultUI;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockDisplayDelegate;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAMessageCenter *messageCenter;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAMessageCenterTest

- (void)setUp {
    [super setUp];

    self.notificationCenter = [NSNotificationCenter defaultCenter];
    self.mockDefaultUI = [self strictMockForClass:[UADefaultMessageCenterUI class]];
    self.mockUser = [self mockForClass:[UAUser class]];
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    self.mockDisplayDelegate = [self strictMockForProtocol:@protocol(UAMessageCenterDisplayDelegate)];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    self.messageCenter = [UAMessageCenter messageCenterWithDataStore:self.dataStore
                                                                user:self.mockUser
                                                         messageList:self.mockMessageList
                                                           defaultUI:self.mockDefaultUI
                                                  notificationCenter:self.notificationCenter
                                                      privacyManager:self.privacyManager];
}


- (void)testDisplay {
    [[self.mockDefaultUI expect] displayMessageCenterAnimated:YES];
    [self.messageCenter display];
    [self.mockDefaultUI verify];
}

- (void)testDisplayAnimated {
    [[self.mockDefaultUI expect] displayMessageCenterAnimated:NO];
    [self.messageCenter display:NO];
    [self.mockDefaultUI verify];
}

- (void)testDisplayMessage {
    [[self.mockDefaultUI expect] displayMessageCenterForMessageID:@"cool" animated:YES];
    [self.messageCenter displayMessageForID:@"cool"];
    [self.mockDefaultUI verify];
}

- (void)testDisplayMessageAnimated {
    [[self.mockDefaultUI expect] displayMessageCenterForMessageID:@"cool" animated:NO];
    [self.messageCenter displayMessageForID:@"cool" animated:NO];
    [self.mockDefaultUI verify];
}

- (void)testDisplayWithDelegate {
    [[self.mockDisplayDelegate expect] displayMessageCenterAnimated:YES];
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;
    [self.messageCenter display];
    [self.mockDisplayDelegate verify];
}

- (void)testDisplayAnimatedWithDelegate {
    [[self.mockDisplayDelegate expect] displayMessageCenterAnimated:NO];
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;
    [self.messageCenter display:NO];
    [self.mockDefaultUI verify];
}

- (void)testDisplayMessageWithDelegate {
    [[self.mockDisplayDelegate expect] displayMessageCenterForMessageID:@"cool" animated:YES];
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;
    [self.messageCenter displayMessageForID:@"cool"];
    [self.mockDefaultUI verify];
}

- (void)testDisplayMessageAnimatedWithDelegate {
    [[self.mockDisplayDelegate expect] displayMessageCenterForMessageID:@"cool" animated:NO];
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;
    [self.messageCenter displayMessageForID:@"cool" animated:NO];
    [self.mockDefaultUI verify];
}

- (void)testComponentEnablement {
    [[self.mockMessageList expect] setEnabled:NO];
    [[self.mockUser expect] setEnabled:NO];
    self.messageCenter.componentEnabled = NO;

    [[self.mockMessageList expect] setEnabled:YES];
    [[self.mockUser expect] setEnabled:YES];
    self.messageCenter.componentEnabled = YES;

    [self.mockMessageList verify];
    [self.mockUser verify];
}

- (void)testUserCreated {
    [[self.mockMessageList expect] retrieveMessageListWithSuccessBlock:OCMOCK_ANY withFailureBlock:OCMOCK_ANY];
    [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
    [self.mockMessageList verify];
}

- (void)testFeatureEnablement {
    [[self.mockMessageList expect] setEnabled:NO];
    [[self.mockUser expect] setEnabled:NO];

    [self.privacyManager disableFeatures:UAFeaturesMessageCenter];

    [[self.mockMessageList expect] setEnabled:YES];
    [[self.mockUser expect] setEnabled:YES];

    [self.privacyManager enableFeatures:UAFeaturesMessageCenter];

    [self.mockMessageList verify];
    [self.mockUser verify];
}

- (void)testURLConfigUpdated {
    [[self.mockMessageList expect] retrieveMessageListWithSuccessBlock:OCMOCK_ANY withFailureBlock:OCMOCK_ANY];
    [self.notificationCenter postNotificationName:UARuntimeConfig.configUpdatedEvent object:nil];
    [self.mockMessageList verify];
}

- (void)testDeepLinks {
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;

    NSURL *validMessage = [NSURL URLWithString:@"uairship://message_center/message/some-message"];
    [[self.mockDisplayDelegate expect] displayMessageCenterForMessageID:@"some-message" animated:OCMOCK_ANY];
    XCTAssertTrue([self.messageCenter deepLink:validMessage]);

    NSURL *trailingSlashMessage = [NSURL URLWithString:@"uairship://message_center/message/some-other-message/"];
    [[self.mockDisplayDelegate expect] displayMessageCenterForMessageID:@"some-other-message" animated:OCMOCK_ANY];
    XCTAssertTrue([self.messageCenter deepLink:trailingSlashMessage]);
    
    NSURL *validCenter = [NSURL URLWithString:@"uairship://message_center"];
    [[self.mockDisplayDelegate expect] displayMessageCenterAnimated:OCMOCK_ANY];
    XCTAssertTrue([self.messageCenter deepLink:validCenter]);

    NSURL *trailingSlashCenter = [NSURL URLWithString:@"uairship://message_center/"];
    [[self.mockDisplayDelegate expect] displayMessageCenterAnimated:OCMOCK_ANY];
    XCTAssertTrue([self.messageCenter deepLink:trailingSlashCenter]);
    
    [self.mockDisplayDelegate verify];
}

- (void)testInvalidDeepLinks {
    self.messageCenter.displayDelegate = self.mockDisplayDelegate;

    [[self.mockDisplayDelegate reject] displayMessageCenterForMessageID:OCMOCK_ANY animated:OCMOCK_ANY];
    [[self.mockDisplayDelegate reject] displayMessageCenterAnimated:OCMOCK_ANY];

    NSURL *tooManyArgs = [NSURL URLWithString:@"uairship://message_center/message/some-message/what"];
    XCTAssertFalse([self.messageCenter deepLink:tooManyArgs]);

    NSURL *wrongHost = [NSURL URLWithString:@"uairship://what/message/some-message"];
    XCTAssertFalse([self.messageCenter deepLink:wrongHost]);
    
    NSURL *wrongScheme = [NSURL URLWithString:@"what://message_center/message/some-message"];
    XCTAssertFalse([self.messageCenter deepLink:wrongScheme]);
    
    [self.mockDisplayDelegate verify];
}


@end
