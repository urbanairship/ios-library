/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory+Internal.h"

@interface UAAPNSRegistrationTest : XCTestCase

@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;

@property (nonatomic, strong) UAAPNSRegistration *pushRegistration;
@property (nonatomic, strong) NSSet<UANotificationCategory *> *testCategories;

@end

@implementation UAAPNSRegistrationTest

- (void)setUp {
    [super setUp];

    self.mockedUserNotificationCenter = [OCMockObject niceMockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Create APNS registration object
    self.pushRegistration = [[UAAPNSRegistration alloc] init];

    //Set ip some categories to use
    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];

    self.testCategories = [NSSet setWithArray:@[defaultCategory, customCategory, anotherCustomCategory]];
}

- (void)tearDown {
    [super tearDown];

    [self.mockedApplication stopMocking];
    [self.mockedUserNotificationCenter stopMocking];

    self.pushRegistration = nil;
}

-(void)testUpdateRegistrationSetsCategories {

    UANotificationOptions expectedOptions = UANotificationOptionAlert & UANotificationOptionBadge;

    // Normalize the test categories
    NSMutableSet *normalizedCategories = [NSMutableSet set];
    // Normalize our abstract categories to iOS-appropriate type
    for (UANotificationCategory *category in self.testCategories) {
        [normalizedCategories addObject:[category asUNNotificationCategory]];
    }

    [[self.mockedUserNotificationCenter expect] setNotificationCategories:normalizedCategories];

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories completionHandler:^(UANotificationOptions options) {
    }];

    [self.mockedUserNotificationCenter verify];
}

-(void)testUpdateRegistration {
    UANotificationOptions expectedOptions = UANotificationOptionAlert | UANotificationOptionBadge;

    // Normalize the test categories
    NSMutableSet *normalizedCategories = [NSMutableSet set];
    for (UANotificationCategory *category in self.testCategories) {
        [normalizedCategories addObject:[category asUNNotificationCategory]];
    }

    // Normalize the options
    UNAuthorizationOptions normalizedOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay);
    normalizedOptions &= expectedOptions;

    [[self.mockedUserNotificationCenter expect] requestAuthorizationWithOptions:normalizedOptions completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(BOOL granted, NSError * _Nullable error) = obj;
        [[self.mockedApplication expect] registerForRemoteNotifications];
        completionBlock(YES, nil);
        return YES;
    }]];

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories completionHandler:^(UANotificationOptions options) {
    }];

    [self.mockedUserNotificationCenter verify];
}

-(void)testGetCurrentAuthorization {

    // These expected options must match mocked UNNotificationSettings object below for the test to be valid
    UANotificationOptions expectedOptions =  UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound | UANotificationOptionCarPlay;

    // Mock UNNotificationSettings object to match expected options since we can't initialize one
    id mockNotificationSettings = [OCMockObject niceMockForClass:[UNNotificationSettings class]];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNAuthorizationStatusAuthorized)] authorizationStatus];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] alertSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] soundSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] badgeSetting];
    [[[mockNotificationSettings stub] andReturnValue:OCMOCK_VALUE(UNNotificationSettingEnabled)] carPlaySetting];

    typedef void (^NotificationSettingsReturnBlock)(UNNotificationSettings * _Nonnull settings);

    [[[self.mockedUserNotificationCenter stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NotificationSettingsReturnBlock returnBlock = (__bridge NotificationSettingsReturnBlock)arg;
        returnBlock(mockNotificationSettings);

    }] getNotificationSettingsWithCompletionHandler:OCMOCK_ANY];

    [self.pushRegistration getCurrentAuthorizationOptionsWithCompletionHandler:^(UANotificationOptions options) {
        XCTAssertTrue(options == expectedOptions);
    }];
}

@end

