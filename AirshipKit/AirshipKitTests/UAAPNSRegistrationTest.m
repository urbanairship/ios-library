/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@interface UAAPNSRegistrationTest : UABaseTest

@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockedUserNotificationCenter;

@property (nonatomic, strong) UAAPNSRegistration *pushRegistration;
@property (nonatomic, strong) NSSet<UANotificationCategory *> *testCategories;

@end

@implementation UAAPNSRegistrationTest

- (void)setUp {
    [super setUp];

    self.mockedUserNotificationCenter = [self mockForClass:[UNUserNotificationCenter class]];
    [[[self.mockedUserNotificationCenter stub] andReturn:self.mockedUserNotificationCenter] currentNotificationCenter];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    // Create APNS registration object
    self.pushRegistration = [[UAAPNSRegistration alloc] init];

    //Set ip some categories to use
    UANotificationCategory *defaultCategory = [UANotificationCategory categoryWithIdentifier:@"defaultCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *customCategory = [UANotificationCategory categoryWithIdentifier:@"customCategory" actions:@[]  intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
    UANotificationCategory *anotherCustomCategory = [UANotificationCategory categoryWithIdentifier:@"anotherCustomCategory" actions:@[] intentIdentifiers:@[] options:UANotificationCategoryOptionNone];

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

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories];

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

    [self.pushRegistration updateRegistrationWithOptions:expectedOptions categories:self.testCategories];

    [self.mockedUserNotificationCenter verify];
}

-(void)testGetCurrentAuthorization {

    // These expected options must match mocked UNNotificationSettings object below for the test to be valid
    UANotificationOptions expectedOptions =  UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound | UANotificationOptionCarPlay;

    // Mock UNNotificationSettings object to match expected options since we can't initialize one
    id mockNotificationSettings = [self mockForClass:[UNNotificationSettings class]];
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

