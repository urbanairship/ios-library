/* Copyright Airship and Contributors */

import XCTest

import AirshipCore

final class VersionMatcherTest: XCTestCase {
    func testIsExactVersion() {
        XCTAssertTrue(VersionMatcher.isExactVersion("1"))
        XCTAssertTrue(VersionMatcher.isExactVersion("1.1"))
        XCTAssertTrue(VersionMatcher.isExactVersion("1.1.1"))
        XCTAssertTrue(VersionMatcher.isExactVersion("1.10000"))
        XCTAssertTrue(VersionMatcher.isExactVersion("1.10000.1"))

        XCTAssertFalse(VersionMatcher.isExactVersion(""))
        XCTAssertFalse(VersionMatcher.isExactVersion("a"))
        XCTAssertFalse(VersionMatcher.isExactVersion("1.a"))
        XCTAssertFalse(VersionMatcher.isExactVersion("1."))
        XCTAssertFalse(VersionMatcher.isExactVersion(".1"))
        XCTAssertFalse(VersionMatcher.isExactVersion("a.1"))
        XCTAssertFalse(VersionMatcher.isExactVersion("1.10000.1.5"))

        XCTAssertTrue(VersionMatcher.isExactVersion(" 1"))
        XCTAssertTrue(VersionMatcher.isExactVersion("1 "))
        XCTAssertTrue(VersionMatcher.isExactVersion(" 1 "))

        XCTAssertFalse(VersionMatcher.isExactVersion(" a"))
        XCTAssertFalse(VersionMatcher.isExactVersion("a "))
        XCTAssertFalse(VersionMatcher.isExactVersion(" a "))
    }

    func testIsSubVersion() {
        XCTAssertTrue(VersionMatcher.isSubVersion("1+"))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.+"))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.2+"))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.2.+"))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.2.3+"))
        XCTAssertTrue(VersionMatcher.isSubVersion(" 1.0+"))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.0+ "))
        XCTAssertTrue(VersionMatcher.isSubVersion(" 1.0+ "))
        XCTAssertTrue(VersionMatcher.isSubVersion("1.0. +"))
        XCTAssertTrue(VersionMatcher.isSubVersion("+"))

        XCTAssertFalse(VersionMatcher.isSubVersion(""))
        XCTAssertFalse(VersionMatcher.isSubVersion("1.0.*"))
        XCTAssertFalse(VersionMatcher.isSubVersion("1.0++"))
        XCTAssertFalse(VersionMatcher.isSubVersion("1.0++"))
        XCTAssertFalse(VersionMatcher.isSubVersion("1.2.3.+"))
    }

    func testIsVersionRange() {
        XCTAssertTrue(VersionMatcher.isVersionRange("[1.0,2.0]"))
        XCTAssertTrue(VersionMatcher.isVersionRange("[1.0,2.0["))
        XCTAssertTrue(VersionMatcher.isVersionRange("]1.0,2.0]"))
        XCTAssertTrue(VersionMatcher.isVersionRange("]1.0,2.0["))
        XCTAssertTrue(VersionMatcher.isVersionRange("[1.0,)"))
        XCTAssertTrue(VersionMatcher.isVersionRange("]1.0,)"))
        XCTAssertTrue(VersionMatcher.isVersionRange("(,2.0]"))
        XCTAssertTrue(VersionMatcher.isVersionRange("(,2.0["))

        XCTAssertTrue(VersionMatcher.isVersionRange(" (,2.0["))
        XCTAssertTrue(VersionMatcher.isVersionRange("(,2.0[ "))
        XCTAssertTrue(VersionMatcher.isVersionRange(" (,2.0[ "))
        XCTAssertTrue(VersionMatcher.isVersionRange("( ,2.0["))
        XCTAssertTrue(VersionMatcher.isVersionRange("(, 2.0["))
        XCTAssertTrue(VersionMatcher.isVersionRange("( , 2.0[ "))

        XCTAssertFalse(VersionMatcher.isVersionRange("(,2.0)"))
        XCTAssertFalse(VersionMatcher.isVersionRange("),2.0]"))
        XCTAssertFalse(VersionMatcher.isVersionRange("[1.0,("))
        XCTAssertFalse(VersionMatcher.isVersionRange("],2.0]"))
        XCTAssertFalse(VersionMatcher.isVersionRange("[1.0,]"))
        XCTAssertFalse(VersionMatcher.isVersionRange("[1.0,2.0)"))
        XCTAssertFalse(VersionMatcher.isVersionRange("(1.0,2.0]"))
    }

    func testExactVersionMatcher() {
        let matcher = VersionMatcher(versionConstraint: "1.0")!
        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate("1.0"))
        XCTAssertTrue(matcher.evaluate(" 1.0"))
        XCTAssertTrue(matcher.evaluate("1.0 "))
        XCTAssertTrue(matcher.evaluate(" 1.0 "))

        XCTAssertFalse(matcher.evaluate(" 0.9"))
        XCTAssertFalse(matcher.evaluate("1.1 "))
        XCTAssertFalse(matcher.evaluate(" 2.0"))
        XCTAssertFalse(matcher.evaluate(" 2.0 "))

        let matcher2 = VersionMatcher(versionConstraint: " 1.0")!
        XCTAssertNotNil(matcher2)
        XCTAssertTrue(matcher2.evaluate("1.0"))
        XCTAssertTrue(matcher2.evaluate(" 1.0"))
        XCTAssertTrue(matcher2.evaluate("1.0 "))
        XCTAssertTrue(matcher2.evaluate(" 1.0 "))

        XCTAssertFalse(matcher2.evaluate(" 0.9"))
        XCTAssertFalse(matcher2.evaluate("1.1 "))
        XCTAssertFalse(matcher2.evaluate(" 2.0"))
        XCTAssertFalse(matcher2.evaluate(" 2.0 "))

        let matcher3 = VersionMatcher(versionConstraint: "1.0   ")!
        XCTAssertNotNil(matcher3)
        XCTAssertTrue(matcher3.evaluate("1.0"))
        XCTAssertTrue(matcher3.evaluate(" 1.0"))
        XCTAssertTrue(matcher3.evaluate("1.0 "))
        XCTAssertTrue(matcher3.evaluate(" 1.0 "))

        XCTAssertFalse(matcher3.evaluate(" 0.9"))
        XCTAssertFalse(matcher3.evaluate("1.1 "))
        XCTAssertFalse(matcher3.evaluate(" 2.0"))
        XCTAssertFalse(matcher3.evaluate(" 2.0 "))

        let matcher4 = VersionMatcher(versionConstraint: " 1.0 ")!
        XCTAssertNotNil(matcher4)
        XCTAssertTrue(matcher4.evaluate("1.0"))
        XCTAssertTrue(matcher4.evaluate(" 1.0"))
        XCTAssertTrue(matcher4.evaluate("1.0 "))
        XCTAssertTrue(matcher4.evaluate(" 1.0 "))

        XCTAssertFalse(matcher4.evaluate(" 0.9"))
        XCTAssertFalse(matcher4.evaluate("1.1 "))
        XCTAssertFalse(matcher4.evaluate(" 2.0"))
        XCTAssertFalse(matcher4.evaluate(" 2.0 "))
    }

    func testSubVersionMatcher() {
        let matcher = VersionMatcher(versionConstraint: "1.0.+")!
        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate("1.0.1"))
        XCTAssertTrue(matcher.evaluate("1.0.5"))
        XCTAssertTrue(matcher.evaluate("1.0.a"))

        XCTAssertFalse(matcher.evaluate("1.0"))
        XCTAssertFalse(matcher.evaluate("1"))
        XCTAssertFalse(matcher.evaluate("1.01"))
        XCTAssertFalse(matcher.evaluate("1.11"))
        XCTAssertFalse(matcher.evaluate("2"))

        let matcher2 = VersionMatcher(versionConstraint: "1.0+")!
        XCTAssertNotNil(matcher2)
        XCTAssertTrue(matcher2.evaluate("1.0"))
        XCTAssertTrue(matcher2.evaluate("1.0.1"))
        XCTAssertTrue(matcher2.evaluate("1.00"))
        XCTAssertTrue(matcher2.evaluate("1.01"))

        XCTAssertFalse(matcher2.evaluate("1"))
        XCTAssertFalse(matcher2.evaluate("1.11"))
        XCTAssertFalse(matcher2.evaluate("2"))
    }

    func testVersionRangeMatcher() {
        let matcher = VersionMatcher(versionConstraint: "[1.0, 2.0]")!
        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate("1.0"))
        XCTAssertTrue(matcher.evaluate("1.0.1"))
        XCTAssertTrue(matcher.evaluate("1.5"))
        XCTAssertTrue(matcher.evaluate("1.9.9"))
        XCTAssertTrue(matcher.evaluate("2.0"))

        XCTAssertFalse(matcher.evaluate("0.0"))
        XCTAssertFalse(matcher.evaluate("0.9.9"))
        XCTAssertFalse(matcher.evaluate("2.0.1"))
        XCTAssertFalse(matcher.evaluate("3.0"))
    }



}
