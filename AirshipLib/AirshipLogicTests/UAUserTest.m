
#import "UAUserTest.h"
#import "UAUser+Internal.h"

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

@interface UAUserTest()
@property(nonatomic, strong) UAUser *user;
@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];
    self.user = [UAUser defaultUser];

    // set an app key to allow the keychain utils to look for a username
    self.user.appKey = @"9Q1tVTl0RF16baYKYp8HPQ";
}

- (void)tearDown {
    // Tear-down code here.
    [super tearDown];
}

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values
    XCTAssertNotNil(self.user, @"we should at least have a user");
    XCTAssertNil(self.user.username, @"user name should be nil");
    XCTAssertNil(self.user.password, @"password should be nil");
    XCTAssertNil(self.user.url, @"url should be nil");
}

- (void)testDefaultUserCreated {
    XCTAssertFalse([self.user defaultUserCreated], @"an uninitialized user is not created");
}

@end