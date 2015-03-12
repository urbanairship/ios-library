/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxPushHandler+Internal.h"
#import "UAInboxMessageList.h"
#import "UAirship.h"

@interface UAInboxPushHandlerTest : XCTestCase
@property (nonatomic, strong) UAInboxMessage *message;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) UAInboxPushHandler *pushHandler;
@property (nonatomic, strong) id mockedUAInboxPushHandlerDelegate;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockInbox;

@end

@implementation UAInboxPushHandlerTest


- (void)setUp {
    [super setUp];
    self.pushHandler = [[UAInboxPushHandler alloc] init];
    self.message = [[UAInboxMessage alloc] init];

    self.mockMessageList = [OCMockObject niceMockForClass:[UAInboxMessageList class]];
    [UAirship inbox].messageList = self.mockMessageList;

    self.mockedUAInboxPushHandlerDelegate = [OCMockObject niceMockForProtocol:@protocol(UAInboxPushHandlerDelegate)];
    self.pushHandler.delegate = self.mockedUAInboxPushHandlerDelegate;

    self.mockInbox = [OCMockObject niceMockForClass:[UAInbox class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];

}

- (void)tearDown {
    [super tearDown];
    [self.mockMessageList stopMocking];
    [self.mockedUAInboxPushHandlerDelegate stopMocking];
}

/*
 * Test messageListLoadSucceeded launches message
 */
- (void)testMessageListLoadSucceededLaunchMesg {
    self.pushHandler.hasLaunchMessage = YES;
    self.pushHandler.viewingMessageID = @"viewingMessageID";

    [[[self.mockMessageList stub] andReturn:self.message] messageForID:@"viewingMessageID"];

    [[self.mockedUAInboxPushHandlerDelegate expect] launchRichPushMessageAvailable:self.message];

    [self.pushHandler messageListLoadSucceeded];

    XCTAssertFalse(self.pushHandler.hasLaunchMessage, "Expect hasLaunchMessage to be false");
    XCTAssertNil(self.pushHandler.viewingMessageID, "Expect viewingMessageID to be nil");
    XCTAssertNoThrow([self.mockedUAInboxPushHandlerDelegate verify], "launchRichPushMessageAvailable should be called");
}

/*
 * Test messageListLoadSucceeded does not launch a nil message
 */
- (void)testMessageListLoadSucceededNilLaunchMesg {
    self.pushHandler.hasLaunchMessage = YES;
    self.pushHandler.viewingMessageID = @"viewingMessageID";
    UAInboxMessage *message = nil;

    [[[self.mockMessageList stub] andReturn:message] messageForID:@"viewingMessageID"];

    [[self.mockedUAInboxPushHandlerDelegate expect] launchRichPushMessageAvailable:self.message];

    [self.pushHandler messageListLoadSucceeded];

    XCTAssertTrue(self.pushHandler.hasLaunchMessage, "Expect hasLaunchMessage to be true");
    XCTAssertNil(self.pushHandler.viewingMessageID, "Expect viewingMessageID to be nil");
    XCTAssertThrows([self.mockedUAInboxPushHandlerDelegate verify], "launchRichPushMessageAvailable should not be called");
}

/*
 * Test messageListLoadSucceeded displays message
 */
- (void)testMessageListLoadSucceededDisplayMesg {
    self.pushHandler.hasLaunchMessage = NO;
    self.pushHandler.viewingMessageID = @"viewingMessageID";

    [[[self.mockMessageList stub] andReturn:self.message] messageForID:@"viewingMessageID"];

    [[self.mockedUAInboxPushHandlerDelegate expect] richPushMessageAvailable:self.message];

    [self.pushHandler messageListLoadSucceeded];

    XCTAssertFalse(self.pushHandler.hasLaunchMessage, "Expect hasLaunchMessage to be false");
    XCTAssertNil(self.pushHandler.viewingMessageID, "Expect viewingMessageID to be nil");
    XCTAssertNoThrow([self.mockedUAInboxPushHandlerDelegate verify], "richPushMessageAvailable should be called");
}

/*
 * Test messageListLoadSucceeded does not display a nil message
 */
- (void)testMessageListLoadSucceededNilDisplayMesg {
    self.pushHandler.hasLaunchMessage = NO;
    self.pushHandler.viewingMessageID = @"viewingMessageID";
    UAInboxMessage *message = nil;

    [[[self.mockMessageList stub] andReturn:message] messageForID:@"viewingMessageID"];

    [[self.mockedUAInboxPushHandlerDelegate expect] richPushMessageAvailable:self.message];

    [self.pushHandler messageListLoadSucceeded];

    XCTAssertFalse(self.pushHandler.hasLaunchMessage, "Expect hasLaunchMessage to be false");
    XCTAssertNil(self.pushHandler.viewingMessageID, "Expect viewingMessageID to be nil");
    XCTAssertThrows([self.mockedUAInboxPushHandlerDelegate verify], "richPushMessageAvailable should not be called");
}

@end
