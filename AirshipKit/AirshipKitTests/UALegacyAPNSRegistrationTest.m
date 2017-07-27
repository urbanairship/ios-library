/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALegacyAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@interface UALegacyAPNSRegistrationTest : UABaseTest

@property (nonatomic, strong) id mockedApplication;

@property (nonatomic, strong) UALegacyAPNSRegistration *pushRegistration;
@property (nonatomic, strong) NSSet<UANotificationCategory *> *testCategories;

@end

@implementation UALegacyAPNSRegistrationTest

- (void)setUp {
    [super setUp];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
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
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    for (UANotificationCategory *category in self.testCategories) {
        [normalizedCategories addObject:[category asUIUserNotificationCategory]];
    }

    [[self.mockedApplication expect] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:normalizedOptions
                                                                                                        categories:normalizedCategories]];
#pragma GCC diagnostic pop
    [self.pushRegistration updateRegistrationWithOptions:options categories:self.testCategories];

    [self.mockedApplication verify];
}

@end
