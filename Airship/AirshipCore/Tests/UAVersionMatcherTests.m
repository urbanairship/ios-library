/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAVersionMatcher.h"

@interface UAVersionMatcherTests : UABaseTest

@end


@implementation UAVersionMatcherTests

- (void)testIsExactVersion {
    // These examples come from Apple's dev site:
    // https://developer.apple.com/library/content/technotes/tn2420/_index.html#//apple_ref/doc/uid/DTS40016603-CH1-TWO_NAMING_CONVENTIONS_FOR_VERSION_NUMBERS_AND_BUILD_NUMBERS
    
    // Legal examples
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1"]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1.1"]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1.1.1"]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1.10000"]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1.10000.1"]);
    
    // Illegal examples
    XCTAssertFalse([UAVersionMatcher isExactVersion:@""]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"a"]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"1.a"]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"1."]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@".1"]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"a.1"]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"1.10000.1.5"]);
    
    // add some whitespace
    XCTAssertTrue([UAVersionMatcher isExactVersion:@" 1"]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@"1 "]);
    XCTAssertTrue([UAVersionMatcher isExactVersion:@" 1 "]);

    XCTAssertFalse([UAVersionMatcher isExactVersion:@" a"]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@"a "]);
    XCTAssertFalse([UAVersionMatcher isExactVersion:@" a "]);
}

- (void)testIsSubVersion {
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.2+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.2.+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.2.3+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@" 1.0+"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.0+ "]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@" 1.0+ "]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"1.0. +"]);
    XCTAssertTrue([UAVersionMatcher isSubVersion:@"+"]);

    XCTAssertFalse([UAVersionMatcher isSubVersion:@""]);
    XCTAssertFalse([UAVersionMatcher isSubVersion:@"1.0.*"]);
    XCTAssertFalse([UAVersionMatcher isSubVersion:@"1.0++"]);
    XCTAssertFalse([UAVersionMatcher isSubVersion:@"1.0++"]);
    XCTAssertFalse([UAVersionMatcher isSubVersion:@"1.2.3.+"]);
}

- (void)testIsVersionRange {
    // These examples come from Apache's Ant/Ivy dev site:
    // http://ant.apache.org/ivy/history/latest-milestone/settings/version-matchers.html
    
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"[1.0,2.0]"]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"[1.0,2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"]1.0,2.0]"]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"]1.0,2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"[1.0,)"]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"]1.0,)"]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"(,2.0]"]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"(,2.0["]);

    // add some whitespace
    XCTAssertTrue([UAVersionMatcher isVersionRange:@" (,2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"(,2.0[ "]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@" (,2.0[ "]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"( ,2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"(, 2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@"( , 2.0["]);
    XCTAssertTrue([UAVersionMatcher isVersionRange:@" ( , 2.0[ "]);

    XCTAssertFalse([UAVersionMatcher isVersionRange:@"(,2.0)"]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"),2.0]"]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"[1.0,("]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"],2.0]"]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"[1.0,]"]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"[1.0,2.0)"]);
    XCTAssertFalse([UAVersionMatcher isVersionRange:@"(1.0,2.0]"]);
}

- (void)testExactVersionMatcher {
    UAVersionMatcher *matcher = [UAVersionMatcher matcherWithVersionConstraint:@"1.0"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0 "]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0 "]);
    
    XCTAssertFalse([matcher evaluateObject:@" 0.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.1 "]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0"]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 "]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" 1.0"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0 "]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0 "]);
    
    XCTAssertFalse([matcher evaluateObject:@" 0.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.1 "]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0"]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 "]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"1.0   "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0 "]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0 "]);
    
    XCTAssertFalse([matcher evaluateObject:@" 0.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.1 "]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0"]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 "]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" 1.0 "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0 "]);
    XCTAssertTrue([matcher evaluateObject:@" 1.0 "]);
    
    XCTAssertFalse([matcher evaluateObject:@" 0.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.1 "]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0"]);
    XCTAssertFalse([matcher evaluateObject:@" 2.0 "]);
}

- (void)testSubVersionMatcher {
    UAVersionMatcher *matcher = [UAVersionMatcher matcherWithVersionConstraint:@"1.0.+"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.a"]);
    
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    XCTAssertFalse([matcher evaluateObject:@"1"]);
    XCTAssertFalse([matcher evaluateObject:@"1.01"]);
    XCTAssertFalse([matcher evaluateObject:@"1.11"]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"1.0+"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.00"]);
    XCTAssertTrue([matcher evaluateObject:@"1.01"]);
    
    XCTAssertFalse([matcher evaluateObject:@"1"]);
    XCTAssertFalse([matcher evaluateObject:@"1.11"]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" 1.0+"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.00"]);
    XCTAssertTrue([matcher evaluateObject:@"1.01"]);
    
    XCTAssertFalse([matcher evaluateObject:@"1"]);
    XCTAssertFalse([matcher evaluateObject:@"1.11"]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"1.0+ "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.00"]);
    XCTAssertTrue([matcher evaluateObject:@"1.01"]);
    
    XCTAssertFalse([matcher evaluateObject:@"1"]);
    XCTAssertFalse([matcher evaluateObject:@"1.11"]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" 1.0+  "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.00"]);
    XCTAssertTrue([matcher evaluateObject:@"1.01"]);
    
    XCTAssertFalse([matcher evaluateObject:@"1"]);
    XCTAssertFalse([matcher evaluateObject:@"1.11"]);
    XCTAssertFalse([matcher evaluateObject:@"2"]);

    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"+"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.00"]);
    XCTAssertTrue([matcher evaluateObject:@"1.01"]);
    XCTAssertTrue([matcher evaluateObject:@"1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.11"]);
    XCTAssertTrue([matcher evaluateObject:@"2"]);
}

- (void)testVersionRangeMatcher {
    UAVersionMatcher *matcher = [UAVersionMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"[1.0 ,2.0["];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"]1.0 , 2.0]"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"] 1.0,2.0["];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"[1.0, )"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"3.0"]);
    XCTAssertTrue([matcher evaluateObject:@"999.999.999"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@"]1.0,) "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"3.0"]);
    XCTAssertTrue([matcher evaluateObject:@"999.999.999"]);
    
    XCTAssertFalse([matcher evaluateObject:@"0.0"]);
    XCTAssertFalse([matcher evaluateObject:@"0.9.9"]);
    XCTAssertFalse([matcher evaluateObject:@"1.0"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" (,2.0]"];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"0.0"]);
    XCTAssertTrue([matcher evaluateObject:@"0.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"2.0"]);
    
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    XCTAssertFalse([matcher evaluateObject:@"999.999.999"]);
    
    matcher = [UAVersionMatcher matcherWithVersionConstraint:@" ( , 2.0 [ "];
    XCTAssertNotNil(matcher);
    XCTAssertTrue([matcher evaluateObject:@"0.0"]);
    XCTAssertTrue([matcher evaluateObject:@"0.9.9"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0"]);
    XCTAssertTrue([matcher evaluateObject:@"1.0.1"]);
    XCTAssertTrue([matcher evaluateObject:@"1.5"]);
    XCTAssertTrue([matcher evaluateObject:@"1.9.9"]);
    
    XCTAssertFalse([matcher evaluateObject:@"2.0"]);
    XCTAssertFalse([matcher evaluateObject:@"2.0.1"]);
    XCTAssertFalse([matcher evaluateObject:@"3.0"]);
    XCTAssertFalse([matcher evaluateObject:@"999.999.999"]);
}
@end
