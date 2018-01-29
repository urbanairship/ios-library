/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UAWhitelist.h"
#import "UAConfig.h"

@interface UAWhitelistTest : UABaseTest

@property(nonatomic, strong) UAWhitelist *whitelist;
@property(nonnull, strong) NSArray *scopes;

@end

@implementation UAWhitelistTest

- (void)setUp {
    [super setUp];
    self.whitelist = [[UAWhitelist alloc] init];
    self.scopes = @[@(UAWhitelistScopeJavaScriptInterface), @(UAWhitelistScopeOpenURL), @(UAWhitelistScopeAll)];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test an empty white list rejects all URLs.
 */
- (void)testEmptyWhitelist {
    for (NSNumber *number in self.scopes) {
        UAWhitelistScope scope = (UAWhitelistScope)number.unsignedIntegerValue;
        XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///*"] scope:scope]);
    }
}

/**
 * Test the default white list accepts Urban Airship URLs.
 */
- (void)testDefaultWhitelist {
    UAConfig *config = [UAConfig config];
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:config];

    for (NSNumber *number in self.scopes) {
        UAWhitelistScope scope = (UAWhitelistScope)number.unsignedIntegerValue;

        XCTAssertTrue([whitelist isWhitelisted:[NSURL URLWithString:@"https://device-api.urbanairship.com/api/user/"] scope:scope]);

        // Starbucks
        XCTAssertTrue([whitelist isWhitelisted:[NSURL URLWithString:@"https://sbux-dl.urbanairship.com/binary/token/"] scope:scope]);

        // Landing Page
        XCTAssertTrue([whitelist isWhitelisted:[NSURL URLWithString:@"https://dl.urbanairship.com/aaa/message_id"] scope:scope]);
    }
}

/**
 * Test setting invalid patterns returns false.
 */
- (void)testInvalidPatterns {
    // Not a URL
    XCTAssertFalse([self.whitelist addEntry:@"not a url"]);

    // Missing schemes
    XCTAssertFalse([self.whitelist addEntry:@"www.urbanairship.com"]);
    XCTAssertFalse([self.whitelist addEntry:@"://www.urbanairship.com"]);

    // Invalid schemes
    XCTAssertFalse([self.whitelist addEntry:@"what://*"]);
    XCTAssertFalse([self.whitelist addEntry:@"ftp://*"]);
    XCTAssertFalse([self.whitelist addEntry:@"sftp://*"]);

    // White space in scheme
    XCTAssertFalse([self.whitelist addEntry:@" file://*"]);

    // Invalid hosts
    XCTAssertFalse([self.whitelist addEntry:@"*://what*"]);
    XCTAssertFalse([self.whitelist addEntry:@"*://*what"]);

    // Missing host
    XCTAssertFalse([self.whitelist addEntry:@"*://"]);

    // Missing file path
    XCTAssertFalse([self.whitelist addEntry:@"file://"]);

    // Invalid file path
    XCTAssertFalse([self.whitelist addEntry:@"file://*"]);
}

/**
 * Test international URLs.
 */
- (void)testInternationalDomainsNotWhitelisted {
    //NSURL can't handle these
    XCTAssertFalse([self.whitelist addEntry:@"*://ουτοπία.δπθ.gr"]);
    XCTAssertFalse([self.whitelist addEntry:@"*://müller.com"]);
}

/**
 * Test wild card scheme accepts http and https schemes.
 */
- (void)testSchemeWildcard {
    [self.whitelist addEntry:@"*://www.urbanairship.com"];

    // Reject
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@""]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"urbanairship.com"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"www.urbanairship.com"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"file://www.urbanairship.com"]]);

    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://www.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.urbanairship.com"]]);
}

/**
 * Test scheme matching works.
 */
- (void)testScheme {
    [self.whitelist addEntry:@"https://www.urbanairship.com"];
    [self.whitelist addEntry:@"file:///asset.html"];


    // Reject
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.urbanairship.com"]]);



    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://www.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///asset.html"]]);
}

/**
 * Test regular expression on the host are treated as literals.
 */
- (void)testRegexInHost {
    XCTAssertTrue([self.whitelist addEntry:@"*://[a-z,A-Z]+"]);

    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship"]]);

    // It should match on a host that is equal to [a-z,A-Z]+
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://[a-z,A-Z]%2B"]]);
}

/**
 * Test host matching actually works.
 */
- (void)testHost {

    XCTAssertTrue([self.whitelist addEntry:@"http://www.urbanairship.com"]);
    XCTAssertTrue([self.whitelist addEntry:@"http://oh.hi.marc"]);

    // Reject
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://oh.bye.marc"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.urbanairship.com.hackers.io"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://omg.www.urbanairship.com.hackers.io"]]);


    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://oh.hi.marc"]]);
}

/**
 * Test wild card the host accepts any host.
 */
- (void)testHostWildcard {
    XCTAssertTrue([self.whitelist addEntry:@"http://*"]);

    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://what.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http:///android-asset/test.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://www.anything.com"]]);
}

/**
 * Test wild card for subdomain accepts any subdomain, including no subdomain.
 */
- (void)testHostWildcardSubdomain {
    XCTAssertTrue([self.whitelist addEntry:@"http://*.urbanairship.com"]);

    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://what.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://hi.urbanairship.com"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://urbanairship.com"]]);

    // Reject
    XCTAssertFalse(([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://lololurbanairship.com"]]));
}

/**
 * Test wild card matcher matches any url that has a valid file path or http/https url.
 */
- (void)testWildcardMatcher {
    XCTAssertTrue([self.whitelist addEntry:@"*"]);

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///what/oh/hi"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://hi.urbanairship.com/path"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"http://urbanairship.com"]]);
}

/**
 * Test file paths.
 */
- (void)testFilePaths {
    XCTAssertTrue([self.whitelist addEntry:@"file:///foo/index.html"]);

    // Reject
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/test.html"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/bar/index.html"]]);

    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/index.html"]]);
}

/**
 * Test file paths with wild cards.
 */
- (void)testFilePathsWildCard {
    XCTAssertTrue([self.whitelist addEntry:@"file:///foo/bar.html"]);
    XCTAssertTrue([self.whitelist addEntry:@"file:///foo/*"]);

    // Reject
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foooooooo/bar.html"]]);

    // Accept
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/test.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/bar/index.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"file:///foo/bar.html"]]);
}

/**
 * Test paths in http/https URLs.
 */
- (void)testURLPaths {
    [self.whitelist addEntry:@"*://*.urbanairship.com/accept.html"];
    [self.whitelist addEntry:@"*://*.urbanairship.com/anythingHTML/*.html"];
    [self.whitelist addEntry:@"https://urbanairship.com/what/index.html"];

    // Reject

    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/reject.html"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/image.png"]]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/image.png"]]);

    // Accept

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/index.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/test.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/foo/bar/index.html"]]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/what/index.html"]]);
}

- (void)testScope {
    [self.whitelist addEntry:@"*://*.urbanairship.com/accept-js.html" scope:UAWhitelistScopeJavaScriptInterface];
    [self.whitelist addEntry:@"*://*.urbanairship.com/accept-url.html" scope:UAWhitelistScopeOpenURL];
    [self.whitelist addEntry:@"*://*.urbanairship.com/accept-all.html" scope:UAWhitelistScopeAll];

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAWhitelistScopeJavaScriptInterface]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAWhitelistScopeOpenURL]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAWhitelistScopeAll]);

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAWhitelistScopeOpenURL]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAWhitelistScopeJavaScriptInterface]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAWhitelistScopeAll]);

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAWhitelistScopeAll]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAWhitelistScopeJavaScriptInterface]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAWhitelistScopeOpenURL]);
}

- (void)testDisableOpenURLWhitelisting {
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://someurl.com"] scope:UAWhitelistScopeOpenURL]);

    self.whitelist.openURLWhitelistingEnabled = NO;

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://someurl.com"] scope:UAWhitelistScopeOpenURL]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://someurl.com"] scope:UAWhitelistScopeJavaScriptInterface]);
    XCTAssertFalse([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://someurl.com"] scope:UAWhitelistScopeAll]);
}

- (void)testAddAllScopesSeparately {
    [self.whitelist addEntry:@"*://*.urbanairship.com/all.html" scope:UAWhitelistScopeOpenURL];
    [self.whitelist addEntry:@"*://*.urbanairship.com/all.html" scope:UAWhitelistScopeJavaScriptInterface];

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAWhitelistScopeAll]);
}

- (void)testAllScopeMatchesInnerScopes {
    [self.whitelist addEntry:@"*://*.urbanairship.com/all.html" scope:UAWhitelistScopeAll];

    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAWhitelistScopeJavaScriptInterface]);
    XCTAssertTrue([self.whitelist isWhitelisted:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAWhitelistScopeOpenURL]);
}

@end
