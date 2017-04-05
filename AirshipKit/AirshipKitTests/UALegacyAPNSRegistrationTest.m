/* Copyright 2017 Urban Airship and Contributors */

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
    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UANotificationCategoryOptionNone];

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
