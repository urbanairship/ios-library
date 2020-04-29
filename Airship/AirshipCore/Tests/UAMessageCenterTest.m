/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenter+Internal.h"
#import "UAUser.h"
#import "UAInboxMessageList.h"
#import "UAComponent+Internal.h"

@interface UAMessageCenterTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockDefaultUI;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockDisplayDelegate;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAMessageCenter *messageCenter;
@end

@implementation UAMessageCenterTest

- (void)setUp {
    [super setUp];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.mockDefaultUI = [self strictMockForClass:[UADefaultMessageCenterUI class]];
    self.mockUser = [self mockForClass:[UAUser class]];
    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    self.mockDisplayDelegate = [self strictMockForProtocol:@protocol(UAMessageCenterDisplayDelegate)];

    self.messageCenter = [UAMessageCenter messageCenterWithDataStore:self.dataStore
                                                                user:self.mockUser
                                                         messageList:self.mockMessageList
                                                           defaultUI:self.mockDefaultUI
                                                  notificationCenter:self.notificationCenter];
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

@end
