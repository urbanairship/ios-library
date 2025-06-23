/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipIvyVersionMatcherTest: XCTestCase {

    func testValidVersions() {
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,2.2.3.4]"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189, 2.2.3.4]"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189-junk, 2.2.3.4-junk]"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3.4"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3.4.+"))
        XCTAssertNotNil(try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3-junk"))
    }

    func testRangeLongVersion() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)")

        XCTAssertTrue(matcher.evaluate(version: "1.22.6"))
        XCTAssertTrue(matcher.evaluate(version: "1.22.6.189"))
        XCTAssertTrue(matcher.evaluate(version: "1.22.6.188"))
        XCTAssertTrue(matcher.evaluate(version: "1.22.7"))
        XCTAssertFalse(matcher.evaluate(version: "1.22.5"))
    }

    func testRangeWithWhiteSpace() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[ 1.2 , 2.0 ]")

        XCTAssertTrue(matcher.evaluate(version: "1.2"))
        XCTAssertTrue(matcher.evaluate(version: "1.2.0"))
        XCTAssertTrue(matcher.evaluate(version: "1.2.1"))
        XCTAssertTrue(matcher.evaluate(version: "2.0"))
        XCTAssertTrue(matcher.evaluate(version: "2.0.0"))

        XCTAssertFalse(matcher.evaluate(version: "1.1"))
        XCTAssertFalse(matcher.evaluate(version: "1.1.0"))
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"))
        XCTAssertFalse(matcher.evaluate(version: "2.1"))
    }

    func testExactVersionMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0")
        XCTAssertTrue(matcher.evaluate(version: "1.0"))
        XCTAssertTrue(matcher.evaluate(version: " 1.0"))
        XCTAssertTrue(matcher.evaluate(version: "1.0 "))
        XCTAssertTrue(matcher.evaluate(version: " 1.0 "))

        XCTAssertFalse(matcher.evaluate(version: " 0.9"))
        XCTAssertFalse(matcher.evaluate(version: "1.1 "))
        XCTAssertFalse(matcher.evaluate(version: " 2.0"))
        XCTAssertFalse(matcher.evaluate(version: " 2.0 "))

        let matcher2 = try AirshipIvyVersionMatcher(versionConstraint: " 1.0")
        XCTAssertTrue(matcher2.evaluate(version: "1.0"))
        XCTAssertTrue(matcher2.evaluate(version: " 1.0"))
        XCTAssertTrue(matcher2.evaluate(version: "1.0 "))
        XCTAssertTrue(matcher2.evaluate(version: " 1.0 "))

        XCTAssertFalse(matcher2.evaluate(version: " 0.9"))
        XCTAssertFalse(matcher2.evaluate(version: "1.1 "))
        XCTAssertFalse(matcher2.evaluate(version: " 2.0"))
        XCTAssertFalse(matcher2.evaluate(version: " 2.0 "))

        let matcher3 = try AirshipIvyVersionMatcher(versionConstraint: "1.0   ")
        XCTAssertTrue(matcher3.evaluate(version: "1.0"))
        XCTAssertTrue(matcher3.evaluate(version: " 1.0"))
        XCTAssertTrue(matcher3.evaluate(version: "1.0 "))
        XCTAssertTrue(matcher3.evaluate(version: " 1.0 "))

        XCTAssertFalse(matcher3.evaluate(version: " 0.9"))
        XCTAssertFalse(matcher3.evaluate(version: "1.1 "))
        XCTAssertFalse(matcher3.evaluate(version: " 2.0"))
        XCTAssertFalse(matcher3.evaluate(version: " 2.0 "))

        let matcher4 = try AirshipIvyVersionMatcher(versionConstraint: " 1.0 ")
        XCTAssertTrue(matcher4.evaluate(version: "1.0"))
        XCTAssertTrue(matcher4.evaluate(version: " 1.0"))
        XCTAssertTrue(matcher4.evaluate(version: "1.0 "))
        XCTAssertTrue(matcher4.evaluate(version: " 1.0 "))

        XCTAssertFalse(matcher4.evaluate(version: " 0.9"))
        XCTAssertFalse(matcher4.evaluate(version: "1.1 "))
        XCTAssertFalse(matcher4.evaluate(version: " 2.0"))
        XCTAssertFalse(matcher4.evaluate(version: " 2.0 "))
    }

    func testSubVersionMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0.+")
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"))
        XCTAssertTrue(matcher.evaluate(version: "1.0.5"))
        XCTAssertTrue(matcher.evaluate(version: "1.0.a"))

        XCTAssertFalse(matcher.evaluate(version: "1.0"))
        XCTAssertFalse(matcher.evaluate(version: "1"))
        XCTAssertFalse(matcher.evaluate(version: "1.01"))
        XCTAssertFalse(matcher.evaluate(version: "1.11"))
        XCTAssertFalse(matcher.evaluate(version: "2"))

        let matcher2 = try AirshipIvyVersionMatcher(versionConstraint: "1.0+")
        XCTAssertNotNil(matcher2)
        XCTAssertTrue(matcher2.evaluate(version: "1.0"))
        XCTAssertTrue(matcher2.evaluate(version: "1.0.1"))
        XCTAssertTrue(matcher2.evaluate(version: "1.00"))
        XCTAssertTrue(matcher2.evaluate(version: "1.01"))

        XCTAssertFalse(matcher2.evaluate(version: "1"))
        XCTAssertFalse(matcher2.evaluate(version: "1.11"))
        XCTAssertFalse(matcher2.evaluate(version: "2"))
    }

    func testVersionRangeMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, 2.0]")
        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate(version: "1.0"))
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"))
        XCTAssertTrue(matcher.evaluate(version: "1.5"))
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"))
        XCTAssertTrue(matcher.evaluate(version: "2.0"))

        XCTAssertFalse(matcher.evaluate(version: "0.0"))
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"))
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"))
        XCTAssertFalse(matcher.evaluate(version: "3.0"))
    }

    func testSubVersionIgnoresVersionQualifiers() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0-rc1+")
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1.01-beta"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "2-SNAPSHOT"));
    }


    func testExactVersion() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-beta"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-rc"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-rc1"));
        XCTAssertTrue(matcher.evaluate(version: " 1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1");
        XCTAssertTrue(matcher.evaluate(version: "1"));
        XCTAssertTrue(matcher.evaluate(version: "1-SNAPSHOT"));

        XCTAssertFalse(matcher.evaluate(version: " 0.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.1 "));
        XCTAssertFalse(matcher.evaluate(version: " 2.0"));
        XCTAssertFalse(matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: " 1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0 "));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0-beta"));

        XCTAssertFalse(matcher.evaluate(version: " 0.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.1 "));
        XCTAssertFalse(matcher.evaluate(version: " 2.0"));
        XCTAssertFalse(matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0   ");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: " 1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0-rc01 "));

        XCTAssertFalse(matcher.evaluate(version: " 0.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.1 "));
        XCTAssertFalse(matcher.evaluate(version: " 2.0"));
        XCTAssertFalse(matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0 ");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: " 1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0 "));
        XCTAssertTrue(matcher.evaluate(version: " 1.0-SNAPSHOT"));

        XCTAssertFalse(matcher.evaluate(version: " 0.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.1 "));
        XCTAssertFalse(matcher.evaluate(version: " 2.0"));
        XCTAssertFalse(matcher.evaluate(version: " 2.0 "));
    }

    func testSubVersion() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0.+");
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.a"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.0-SNAPSHOT"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.0"));
        XCTAssertFalse(matcher.evaluate(version: "1.01"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertFalse(matcher.evaluate(version: "1.1-beta"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0+");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1.01-beta"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0+");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1.01-beta"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0+ ");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1.01-beta"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0+  ");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1.01-beta"));

        XCTAssertFalse(matcher.evaluate(version: "1"));
        XCTAssertFalse(matcher.evaluate(version: "1.11"));
        XCTAssertFalse(matcher.evaluate(version: "2"));
        XCTAssertFalse(matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "+");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.00"));
        XCTAssertTrue(matcher.evaluate(version: "1.01"));
        XCTAssertTrue(matcher.evaluate(version: "1"));
        XCTAssertTrue(matcher.evaluate(version: "1.11"));
        XCTAssertTrue(matcher.evaluate(version: "2"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "2.2.2-beta"));
        XCTAssertTrue(matcher.evaluate(version: "2-SNAPSHOT"));
    }

    func testVersionRange() throws  {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, 2.0]");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9-rc1"));
        XCTAssertTrue(matcher.evaluate(version: "2.0-beta"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0 ,2.0[");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9-rc1"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "2.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0-beta"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]1.0 , 2.0]");
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1-beta"));
        XCTAssertTrue(matcher.evaluate(version: "2.0-beta"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "1.0-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "] 1.0,2.0[");
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1-beta"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0-beta"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, )");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));
        XCTAssertTrue(matcher.evaluate(version: "2.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "3.0"));
        XCTAssertTrue(matcher.evaluate(version: "999.999.999"));
        XCTAssertTrue(matcher.evaluate(version: "3.0-SNAPSHOT"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "0.1-rc3"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]1.0,) ");
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));
        XCTAssertTrue(matcher.evaluate(version: "2.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "3.0"));
        XCTAssertTrue(matcher.evaluate(version: "999.999.999"));
        XCTAssertTrue(matcher.evaluate(version: "2.0-alpha01"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "1.0"));
        XCTAssertFalse(matcher.evaluate(version: "1.0-alpha01"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " (,2.0]");
        XCTAssertTrue(matcher.evaluate(version: "0.0"));
        XCTAssertTrue(matcher.evaluate(version: "0.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));
        XCTAssertTrue(matcher.evaluate(version: "2.0-beta3"));

        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "999.999.999"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-alpha01"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " ( , 2.0 [ ");
        XCTAssertTrue(matcher.evaluate(version: "0.0"));
        XCTAssertTrue(matcher.evaluate(version: "0.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.1-rc1"));

        XCTAssertFalse(matcher.evaluate(version: "2.0"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "999.999.999"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-beta33"));
    }

    func testExactConstraintIgnoresVersionQualifiers() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0-beta");
        XCTAssertTrue(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-alpha01"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-beta"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-beta01"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-rc"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-rc1"));
        XCTAssertTrue(matcher.evaluate(version: "1.0"));

        XCTAssertFalse(matcher.evaluate(version: "1.0.0-SNAPSHOT"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-alpha"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-alpha01"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-beta"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-beta01"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-rc"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0-rc1"));
        XCTAssertFalse(matcher.evaluate(version: "1.0.0"));
    }

    func testVersionRangeIgnoresVersionQualifiers() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0-alpha, 2.0-alpha01]");
        XCTAssertTrue(matcher.evaluate(version: "1.0"));
        XCTAssertTrue(matcher.evaluate(version: "1.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "1.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "1.5"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9"));
        XCTAssertTrue(matcher.evaluate(version: "1.9.9-rc1"));
        XCTAssertTrue(matcher.evaluate(version: "2.0-beta"));
        XCTAssertTrue(matcher.evaluate(version: "2.0"));

        XCTAssertFalse(matcher.evaluate(version: "0.0"));
        XCTAssertFalse(matcher.evaluate(version: "0.9.9"));
        XCTAssertFalse(matcher.evaluate(version: "2.0.1"));
        XCTAssertFalse(matcher.evaluate(version: "3.0"));
        XCTAssertFalse(matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]17.0.0-beta,)");
        XCTAssertFalse(matcher.evaluate(version: "17.0.0"));
        XCTAssertFalse(matcher.evaluate(version: "17.0.0-SNAPSHOT"));
        XCTAssertFalse(matcher.evaluate(version: "17.0.0-alpha"));
        XCTAssertFalse(matcher.evaluate(version: "17.0.0-beta"));
        XCTAssertFalse(matcher.evaluate(version: "17.0.0-rc"));

        XCTAssertTrue(matcher.evaluate(version: "17.0.1"));
        XCTAssertTrue(matcher.evaluate(version: "17.0.1-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "17.0.1-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "17.0.1-beta"));
        XCTAssertTrue(matcher.evaluate(version: "17.0.1-rc"));
        XCTAssertTrue(matcher.evaluate(version: "18.0.0"));
        XCTAssertTrue(matcher.evaluate(version: "18.0.0-SNAPSHOT"));
        XCTAssertTrue(matcher.evaluate(version: "18.0.0-alpha"));
        XCTAssertTrue(matcher.evaluate(version: "18.0.0-beta"));
        XCTAssertTrue(matcher.evaluate(version: "999.999.999"));
        XCTAssertTrue(matcher.evaluate(version: "999.999.999-rc"));
    }
}
