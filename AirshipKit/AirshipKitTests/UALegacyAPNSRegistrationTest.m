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
#import "UALegacyAPNSRegistration+Internal.h"
#import "UANotificationCategory+Internal.h"

@interface UALegacyAPNSRegistrationTest : XCTestCase

@property (nonatomic, strong) id mockedApplication;

@property (nonatomic, strong) UALegacyAPNSRegistration *pushRegistration;
@property (nonatomic, strong) NSSet<UANotificationCategory *> *testCategories;

@end

@implementation UALegacyAPNSRegistrationTest

- (void)setUp {
    [super setUp];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    self.pushRegistration = [[UALegacyAPNSRegistration alloc] init];

    //Set ip some categories to use
    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];

    self.testCategories = [NSSet setWithArray:@[defaultCategory, customCategory, anotherCustomCategory]];
}


- (void)tearDown {
    [super tearDown];

    [self.mockedApplication stopMocking];
}


-(void)testUpdateRegistration {
    UANotificationOptions options = UANotificationOptionAlert | UANotificationOptionBadge;
    NSUInteger normalizedOptions = options & (UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound);

    NSMutableSet *normalizedCategories = [NSMutableSet set];
    for (UANotificationCategory *category in self.testCategories) {
        [normalizedCategories addObject:[category asUIUserNotificationCategory]];
    }

    [[self.mockedApplication expect] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:normalizedOptions
                                                                                                        categories:normalizedCategories]];

    [self.pushRegistration updateRegistrationWithOptions:options categories:self.testCategories completionHandler:^(UANotificationOptions options) {
    }];

    [self.mockedApplication verify];
}

@end
