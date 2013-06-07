
#import "UAUserTest.h"
#import "UAUser.h"
#import "UAirship.h"

@interface UAUserTest()

@property(nonatomic, retain) UAUser *user;

@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];
    self.user = [UAUser defaultUser];
    [UAirship takeOff:nil];
    // Set-up code here.
}

- (void)tearDown {
    // Tear-down code here.
    [super tearDown];
}

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values
    STAssertNotNil(self.user, @"we should at least have a user");
    STAssertNil(self.user.username, @"user name should be nil");
    STAssertNil(self.user.password, @"password should be nil");
    STAssertNil(self.user.url, @"url should be nil");
}

- (void)testDefaultUserCreated {
    STAssertFalse([self.user defaultUserCreated], @"an uninitialized user is not created");
}

@end