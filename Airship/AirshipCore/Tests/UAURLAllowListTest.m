/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAAirshipBaseTest.h"
#import "UAURLAllowListScope.h"

@import AirshipCore;

@interface UAURLAllowListTest : UAAirshipBaseTest

@property(nonatomic, strong) UAURLAllowList *URLAllowList;
@property(nonnull, copy) NSArray *scopes;

@property(nonatomic, strong) id mockURLAllowListDelegate;


@end

@implementation UAURLAllowListTest

- (void)setUp {
    [super setUp];
    self.URLAllowList = [[UAURLAllowList alloc] init];
    
    self.scopes = @[@(UAURLAllowListScopeJavaScriptInterface), @(UAURLAllowListScopeOpenURL), @(UAURLAllowListScopeAll)];
    
    self.mockURLAllowListDelegate = [self mockForProtocol:@protocol(UAURLAllowListDelegate)];
}

/**
 * Test an empty allow list rejects all URLs.
 */
- (void)testEmptyURLAllowList {
    for (NSNumber *number in self.scopes) {
        UInt8 scope = number.intValue;
        XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://www.urbanairship.com"] scope:scope]);
        XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///*"] scope:scope]);
    }
}

/**
 * Test the default allow list accepts Airship URLs.
 */
- (void)testDefaultURLAllowList {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";
    config.URLAllowList = @[];

    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];

    UAURLAllowList *URLAllowList = [UAURLAllowList allowListWithConfig:runtimeConfig];

    for (NSNumber *number in self.scopes) {
        UInt8 scope = number.intValue;

        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://device-api.urbanairship.com/api/user/"] scope:scope]);

        // Landing Page
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://dl.urbanairship.com/aaa/message_id"] scope:scope]);

        // EU
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://device-api.asnapieu.com/api/user/"] scope:scope]);
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://dl.asnapieu.com/aaa/message_id"] scope:scope]);
    }

    // YouTube
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeAll]);

    // sms
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"sms:+18675309?body=Hi%20you"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"sms:8675309"] scope:UAURLAllowListScopeOpenURL]);

    // tel
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"tel:+18675309"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"tel:867-5309"] scope:UAURLAllowListScopeOpenURL]);

    // email
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"mailto:name@example.com?subject=The%20subject%20of%20the%20mail"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"mailto:name@example.com"] scope:UAURLAllowListScopeOpenURL]);

    // System settings
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:UIApplicationOpenSettingsURLString] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"app-settings:"] scope:UAURLAllowListScopeOpenURL]);

    // Reject others
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://some-random-url.com"] scope:UAURLAllowListScopeOpenURL]);
}

- (void)testDefaultURLAllowListNoOpenScopeSet {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";

    UARuntimeConfig *runtimeConfig  = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];

    UAURLAllowList *URLAllowList = [UAURLAllowList allowListWithConfig:runtimeConfig];

    for (NSNumber *number in self.scopes) {
        UInt8 scope = number.intValue;

        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://device-api.urbanairship.com/api/user/"] scope:scope]);

        // Landing Page
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://dl.urbanairship.com/aaa/message_id"] scope:scope]);

        // EU
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://device-api.asnapieu.com/api/user/"] scope:scope]);
        XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://dl.asnapieu.com/aaa/message_id"] scope:scope]);
    }

    // YouTube
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertFalse([URLAllowList isAllowed:[NSURL URLWithString:@"https://*.youtube.com"] scope:UAURLAllowListScopeAll]);

    // sms
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"sms:+18675309?body=Hi%20you"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"sms:8675309"] scope:UAURLAllowListScopeOpenURL]);

    // tel
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"tel:+18675309"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"tel:867-5309"] scope:UAURLAllowListScopeOpenURL]);

    // email
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"mailto:name@example.com?subject=The%20subject%20of%20the%20mail"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"mailto:name@example.com"] scope:UAURLAllowListScopeOpenURL]);

    // System settings
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:UIApplicationOpenSettingsURLString] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"app-settings:"] scope:UAURLAllowListScopeOpenURL]);

    // Any
    XCTAssertTrue([URLAllowList isAllowed:[NSURL URLWithString:@"https://some-random-url.com"] scope:UAURLAllowListScopeOpenURL]);

}

/**
 * Test setting invalid patterns returns false.
 */
- (void)testInvalidPatterns {
    // Not a URL
    XCTAssertFalse([self.URLAllowList addEntry:@"not a url"]);

    // Missing schemes
    XCTAssertFalse([self.URLAllowList addEntry:@"www.urbanairship.com"]);
    XCTAssertFalse([self.URLAllowList addEntry:@"://www.urbanairship.com"]);

    // White space in scheme
    XCTAssertFalse([self.URLAllowList addEntry:@" file://*"]);

    // Invalid hosts
    XCTAssertFalse([self.URLAllowList addEntry:@"*://what*"]);
    XCTAssertFalse([self.URLAllowList addEntry:@"*://*what"]);
}


/**
 * Test wild card scheme accepts http and https schemes.
 */
- (void)testSchemeWildcard {
    [self.URLAllowList addEntry:@"*://www.urbanairship.com"];

    XCTAssertTrue([self.URLAllowList addEntry:@"*://www.urbanairship.com"]);
    XCTAssertTrue([self.URLAllowList addEntry:@"cool*story://rad"]);

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@""]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"urbanairship.com"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"www.urbanairship.com"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"cool://rad"]]);


    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"valid://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"cool----story://rad"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"coolstory://rad"]]);
}

/**
 * Test scheme matching works.
 */
- (void)testScheme {
    [self.URLAllowList addEntry:@"https://www.urbanairship.com"];
    [self.URLAllowList addEntry:@"file:///asset.html"];

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.urbanairship.com"]]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///asset.html"]]);
}

/**
 * Test host matching actually works.
 */
- (void)testHost {
    XCTAssertTrue([self.URLAllowList addEntry:@"http://www.urbanairship.com"]);
    XCTAssertTrue([self.URLAllowList addEntry:@"http://oh.hi.marc"]);

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://oh.bye.marc"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.urbanairship.com.hackers.io"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://omg.www.urbanairship.com.hackers.io"]]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://oh.hi.marc"]]);
}

/**
 * Test wild card the host accepts any host.
 */
- (void)testHostWildcard {
    XCTAssertTrue([self.URLAllowList addEntry:@"http://*"]);
    XCTAssertTrue([self.URLAllowList addEntry:@"https://*.coolstory"]);

    // * is only available at the beginning
    XCTAssertFalse([self.URLAllowList addEntry:@"https://*.coolstory.*"]);

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@""]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://cool"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://story"]]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://what.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http:///android-asset/test.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://www.anything.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://coolstory"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.coolstory"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.what.coolstory"]]);
}

/**
 * Test wild card for subdomain accepts any subdomain, including no subdomain.
 */
- (void)testHostWildcardSubdomain {
    XCTAssertTrue([self.URLAllowList addEntry:@"http://*.urbanairship.com"]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://what.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://hi.urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://urbanairship.com"]]);

    // Reject
    XCTAssertFalse(([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://lololurbanairship.com"]]));
}

/**
 * Test wild card matcher matches any url that has a valid file path or http/https url.
 */
- (void)testWildcardMatcher {
    XCTAssertTrue([self.URLAllowList addEntry:@"*"]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///what/oh/hi"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://hi.urbanairship.com/path"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"http://urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"cool.story://urbanairship.com"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"sms:+18664504185?body=Hi"]]);
}

/**
 * Test file paths.
 */
- (void)testFilePaths {
    XCTAssertTrue([self.URLAllowList addEntry:@"file:///foo/index.html"]);

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/test.html"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/bar/index.html"]]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/index.html"]]);
}

/**
 * Test file paths with wild cards.
 */
- (void)testFilePathsWildCard {
    XCTAssertTrue([self.URLAllowList addEntry:@"file:///foo/bar.html"]);
    XCTAssertTrue([self.URLAllowList addEntry:@"file:///foo/*"]);

    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foooooooo/bar.html"]]);

    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/test.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/bar/index.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"file:///foo/bar.html"]]);
}

/**
 * Test paths.
 */
- (void)testURLPaths {
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/accept.html"];
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/anythingHTML/*.html"];
    [self.URLAllowList addEntry:@"https://urbanairship.com/what/index.html"];
    [self.URLAllowList addEntry:@"wild://cool/*"];


    // Reject
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/reject.html"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/image.png"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/image.png"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"wile:///whatever"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"wile:///cool"]]);


    // Accept
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/index.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/test.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://what.urbanairship.com/anythingHTML/foo/bar/index.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/what/index.html"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"wild://cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"wild://cool/"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"wild://cool/path"]]);
}

- (void)testScope {
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/accept-js.html" scope:UAURLAllowListScopeJavaScriptInterface];
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/accept-url.html" scope:UAURLAllowListScopeOpenURL];
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/accept-all.html" scope:UAURLAllowListScopeAll];

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-js.html"] scope:UAURLAllowListScopeAll]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-url.html"] scope:UAURLAllowListScopeAll]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAURLAllowListScopeAll]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/accept-all.html"] scope:UAURLAllowListScopeOpenURL]);
}

- (void)testDisableOpenURLScopeAllowList {
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://someurl.com"] scope:UAURLAllowListScopeOpenURL]);

    [self.URLAllowList addEntry:@"*" scope:UAURLAllowListScopeOpenURL];
     
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://someurl.com"] scope:UAURLAllowListScopeOpenURL]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://someurl.com"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://someurl.com"] scope:UAURLAllowListScopeAll]);
}

- (void)testAddAllScopesSeparately {
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/all.html" scope:UAURLAllowListScopeOpenURL];
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/all.html" scope:UAURLAllowListScopeJavaScriptInterface];

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAURLAllowListScopeAll]);
}

- (void)testAllScopeMatchesInnerScopes {
    [self.URLAllowList addEntry:@"*://*.urbanairship.com/all.html" scope:UAURLAllowListScopeAll];

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAURLAllowListScopeJavaScriptInterface]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"https://urbanairship.com/all.html"] scope:UAURLAllowListScopeOpenURL]);
}

- (void)testDeepLinks {
    // Test any path and undefined host
    XCTAssertTrue([self.URLAllowList addEntry:@"com.urbanairship.one:/*"]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.one://cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.one:cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.one:/cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.one:///cool"]]);

    // Test any host and undefined path

    XCTAssertTrue([self.URLAllowList addEntry:@"com.urbanairship.two://*"]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.two:cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.two://cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.two:/cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.two:///cool"]]);

    // Test any host and any path

    XCTAssertTrue([self.URLAllowList addEntry:@"com.urbanairship.three://*/*"]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.three:cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.three://cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.three:/cool"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.three:///cool"]]);

    // Test specific host and path
    XCTAssertTrue([self.URLAllowList addEntry:@"com.urbanairship.four://*.cool/whatever/*"]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four:cool"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four://cool"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four:/cool"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four:///cool"]]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four://whatever.cool/whatever/"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.four://cool/whatever/indeed"]]);
}

- (void)testRootPath {
    XCTAssertTrue([self.URLAllowList addEntry:@"com.urbanairship.five:/"]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.five:/"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.five:///"]]);

    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"com.urbanairship.five:/cool"]]);
}

- (void)testDelegate {
    // set up a simple URL allow list
    [self.URLAllowList addEntry:@"https://*.urbanairship.com"];
    [self.URLAllowList addEntry:@"https://*.youtube.com" scope:UAURLAllowListScopeOpenURL];

    // Matching URL to be checked
    NSURL *matchingURLToReject = [NSURL URLWithString:@"https://www.youtube.com/watch?v=sYd_-pAfbBw"];
    NSURL *matchingURLToAccept = [NSURL URLWithString:@"https://device-api.urbanairship.com/api/user"];
    NSURL *nonMatchingURL = [NSURL URLWithString:@"https://maps.google.com"];

    UInt8 scope = UAURLAllowListScopeOpenURL;

    // Allow listing when delegate is off
    XCTAssertTrue([self.URLAllowList isAllowed:matchingURLToReject scope:scope]);
    XCTAssertTrue([self.URLAllowList isAllowed:matchingURLToAccept scope:scope]);
    XCTAssertFalse([self.URLAllowList isAllowed:nonMatchingURL scope:scope]);

    // Enable URL allow list delegate
    (void)[[[self.mockURLAllowListDelegate stub] andDo:^(NSInvocation *invocation) {
        NSURL *url;
        BOOL returnValue;
        [invocation getArgument:&url atIndex:2];
        if ([url isEqual:matchingURLToAccept]) {
            returnValue = YES;
            [invocation setReturnValue:&returnValue];
        } else if ([url isEqual:matchingURLToReject]) {
            returnValue = NO;
            [invocation setReturnValue:&returnValue];
        } else if ([url isEqual:nonMatchingURL]) {
            XCTFail(@"Delegate should not be called when URL fails allow listing");
        } else {
            XCTFail(@"Unknown error");
        }
    }] allowURL:OCMOCK_ANY scope:scope];
    self.URLAllowList.delegate = self.mockURLAllowListDelegate;

    // rejected URL should now fail URL allow list test, others should be unchanged
    XCTAssertFalse([self.URLAllowList isAllowed:matchingURLToReject scope:scope]);
    XCTAssertTrue([self.URLAllowList isAllowed:matchingURLToAccept scope:scope]);
    XCTAssertFalse([self.URLAllowList isAllowed:nonMatchingURL scope:scope]);
    
    // Disable URL allow list delegate
    self.URLAllowList.delegate = nil;

    // Should go back to original state when delegate was off
    XCTAssertTrue([self.URLAllowList isAllowed:matchingURLToReject scope:scope]);
    XCTAssertTrue([self.URLAllowList isAllowed:matchingURLToAccept scope:scope]);
    XCTAssertFalse([self.URLAllowList isAllowed:nonMatchingURL scope:scope]);
}

- (void)testSMSPath {
    XCTAssertTrue([self.URLAllowList addEntry:@"sms:86753*9*"]);

    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"sms:86753"]]);
    XCTAssertFalse([self.URLAllowList isAllowed:[NSURL URLWithString:@"sms:867530"]]);

    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"sms:86753191"]]);
    XCTAssertTrue([self.URLAllowList isAllowed:[NSURL URLWithString:@"sms:8675309"]]);
}

@end
