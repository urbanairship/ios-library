/* Copyright Airship and Contributors */

import Testing
import Foundation
@_spi(AirshipInternal) @testable import AirshipBasement

struct AirshipIvyVersionMatcherTest {

    @Test
    func validVersions() {
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,2.2.3.4]")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189, 2.2.3.4]")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189-junk, 2.2.3.4-junk]")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3.4")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3.4.+")) != nil)
        #expect((try? AirshipIvyVersionMatcher(versionConstraint: "1.2.3-junk")) != nil)
    }

    @Test
    func rangeLongVersion() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.22.6.189,)")

        #expect(matcher.evaluate(version: "1.22.6"))
        #expect(matcher.evaluate(version: "1.22.6.189"))
        #expect(matcher.evaluate(version: "1.22.6.188"))
        #expect(matcher.evaluate(version: "1.22.7"))
        #expect(!matcher.evaluate(version: "1.22.5"))
    }

    @Test
    func rangeWithWhiteSpace() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[ 1.2 , 2.0 ]")

        #expect(matcher.evaluate(version: "1.2"))
        #expect(matcher.evaluate(version: "1.2.0"))
        #expect(matcher.evaluate(version: "1.2.1"))
        #expect(matcher.evaluate(version: "2.0"))
        #expect(matcher.evaluate(version: "2.0.0"))

        #expect(!matcher.evaluate(version: "1.1"))
        #expect(!matcher.evaluate(version: "1.1.0"))
        #expect(!matcher.evaluate(version: "2.0.1"))
        #expect(!matcher.evaluate(version: "2.1"))
    }

    @Test
    func exactVersionMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0")
        #expect(matcher.evaluate(version: "1.0"))
        #expect(matcher.evaluate(version: " 1.0"))
        #expect(matcher.evaluate(version: "1.0 "))
        #expect(matcher.evaluate(version: " 1.0 "))

        #expect(!matcher.evaluate(version: " 0.9"))
        #expect(!matcher.evaluate(version: "1.1 "))
        #expect(!matcher.evaluate(version: " 2.0"))
        #expect(!matcher.evaluate(version: " 2.0 "))

        let matcher2 = try AirshipIvyVersionMatcher(versionConstraint: " 1.0")
        #expect(matcher2.evaluate(version: "1.0"))
        #expect(matcher2.evaluate(version: " 1.0"))
        #expect(matcher2.evaluate(version: "1.0 "))
        #expect(matcher2.evaluate(version: " 1.0 "))

        #expect(!matcher2.evaluate(version: " 0.9"))
        #expect(!matcher2.evaluate(version: "1.1 "))
        #expect(!matcher2.evaluate(version: " 2.0"))
        #expect(!matcher2.evaluate(version: " 2.0 "))

        let matcher3 = try AirshipIvyVersionMatcher(versionConstraint: "1.0   ")
        #expect(matcher3.evaluate(version: "1.0"))
        #expect(matcher3.evaluate(version: " 1.0"))
        #expect(matcher3.evaluate(version: "1.0 "))
        #expect(matcher3.evaluate(version: " 1.0 "))

        #expect(!matcher3.evaluate(version: " 0.9"))
        #expect(!matcher3.evaluate(version: "1.1 "))
        #expect(!matcher3.evaluate(version: " 2.0"))
        #expect(!matcher3.evaluate(version: " 2.0 "))

        let matcher4 = try AirshipIvyVersionMatcher(versionConstraint: " 1.0 ")
        #expect(matcher4.evaluate(version: "1.0"))
        #expect(matcher4.evaluate(version: " 1.0"))
        #expect(matcher4.evaluate(version: "1.0 "))
        #expect(matcher4.evaluate(version: " 1.0 "))

        #expect(!matcher4.evaluate(version: " 0.9"))
        #expect(!matcher4.evaluate(version: "1.1 "))
        #expect(!matcher4.evaluate(version: " 2.0"))
        #expect(!matcher4.evaluate(version: " 2.0 "))
    }

    @Test
    func subVersionMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0.+")
        #expect(matcher.evaluate(version: "1.0.1"))
        #expect(matcher.evaluate(version: "1.0.5"))
        #expect(matcher.evaluate(version: "1.0.a"))

        #expect(!matcher.evaluate(version: "1.0"))
        #expect(!matcher.evaluate(version: "1"))
        #expect(!matcher.evaluate(version: "1.01"))
        #expect(!matcher.evaluate(version: "1.11"))
        #expect(!matcher.evaluate(version: "2"))

        let matcher2 = try AirshipIvyVersionMatcher(versionConstraint: "1.0+")
        #expect(matcher2.evaluate(version: "1.0"))
        #expect(matcher2.evaluate(version: "1.0.1"))
        #expect(matcher2.evaluate(version: "1.00"))
        #expect(matcher2.evaluate(version: "1.01"))

        #expect(!matcher2.evaluate(version: "1"))
        #expect(!matcher2.evaluate(version: "1.11"))
        #expect(!matcher2.evaluate(version: "2"))
    }

    @Test
    func versionRangeMatcher() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, 2.0]")
        #expect(matcher.evaluate(version: "1.0"))
        #expect(matcher.evaluate(version: "1.0.1"))
        #expect(matcher.evaluate(version: "1.5"))
        #expect(matcher.evaluate(version: "1.9.9"))
        #expect(matcher.evaluate(version: "2.0"))

        #expect(!matcher.evaluate(version: "0.0"))
        #expect(!matcher.evaluate(version: "0.9.9"))
        #expect(!matcher.evaluate(version: "2.0.1"))
        #expect(!matcher.evaluate(version: "3.0"))
    }

    @Test
    func subVersionIgnoresVersionQualifiers() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0-rc1+")
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1.01-beta"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "2-SNAPSHOT"));
    }


    @Test
    func exactVersion() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0-beta"));
        #expect(matcher.evaluate(version: "1.0-rc"));
        #expect(matcher.evaluate(version: "1.0-rc1"));
        #expect(matcher.evaluate(version: " 1.0"));
        #expect(matcher.evaluate(version: "1.0 "));
        #expect(matcher.evaluate(version: " 1.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1");
        #expect(matcher.evaluate(version: "1"));
        #expect(matcher.evaluate(version: "1-SNAPSHOT"));

        #expect(!matcher.evaluate(version: " 0.9"));
        #expect(!matcher.evaluate(version: "1.1 "));
        #expect(!matcher.evaluate(version: " 2.0"));
        #expect(!matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: " 1.0"));
        #expect(matcher.evaluate(version: "1.0 "));
        #expect(matcher.evaluate(version: " 1.0 "));
        #expect(matcher.evaluate(version: "1.0-alpha "));
        #expect(matcher.evaluate(version: " 1.0-beta"));

        #expect(!matcher.evaluate(version: " 0.9"));
        #expect(!matcher.evaluate(version: "1.1 "));
        #expect(!matcher.evaluate(version: " 2.0"));
        #expect(!matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0   ");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: " 1.0"));
        #expect(matcher.evaluate(version: "1.0 "));
        #expect(matcher.evaluate(version: " 1.0 "));
        #expect(matcher.evaluate(version: " 1.0-rc01 "));

        #expect(!matcher.evaluate(version: " 0.9"));
        #expect(!matcher.evaluate(version: "1.1 "));
        #expect(!matcher.evaluate(version: " 2.0"));
        #expect(!matcher.evaluate(version: " 2.0 "));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0 ");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: " 1.0"));
        #expect(matcher.evaluate(version: "1.0 "));
        #expect(matcher.evaluate(version: " 1.0 "));
        #expect(matcher.evaluate(version: " 1.0-SNAPSHOT"));

        #expect(!matcher.evaluate(version: " 0.9"));
        #expect(!matcher.evaluate(version: "1.1 "));
        #expect(!matcher.evaluate(version: " 2.0"));
        #expect(!matcher.evaluate(version: " 2.0 "));
    }

    @Test
    func subVersion() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0.+");
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.0.5"));
        #expect(matcher.evaluate(version: "1.0.a"));
        #expect(matcher.evaluate(version: "1.0.0-SNAPSHOT"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.0"));
        #expect(!matcher.evaluate(version: "1.01"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(!matcher.evaluate(version: "1.1-beta"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0+");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1.01-beta"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0+");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1.01-beta"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0+ ");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1.01-beta"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " 1.0+  ");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1.01-beta"));

        #expect(!matcher.evaluate(version: "1"));
        #expect(!matcher.evaluate(version: "1.11"));
        #expect(!matcher.evaluate(version: "2"));
        #expect(!matcher.evaluate(version: "2-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "+");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.00"));
        #expect(matcher.evaluate(version: "1.01"));
        #expect(matcher.evaluate(version: "1"));
        #expect(matcher.evaluate(version: "1.11"));
        #expect(matcher.evaluate(version: "2"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "2.2.2-beta"));
        #expect(matcher.evaluate(version: "2-SNAPSHOT"));
    }

    @Test
    func versionRange() throws  {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, 2.0]");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "2.0"));
        #expect(matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "1.9.9-rc1"));
        #expect(matcher.evaluate(version: "2.0-beta"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0 ,2.0[");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "1.9.9-rc1"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "2.0"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "2.0-beta"));
        #expect(!matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]1.0 , 2.0]");
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "2.0"));
        #expect(matcher.evaluate(version: "1.0.1-beta"));
        #expect(matcher.evaluate(version: "2.0-beta"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "1.0"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "1.0-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "] 1.0,2.0[");
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "1.0.1-beta"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "1.0"));
        #expect(!matcher.evaluate(version: "2.0"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "2.0-beta"));
        #expect(!matcher.evaluate(version: "3.0-SNAPSHOT"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0, )");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "2.0"));
        #expect(matcher.evaluate(version: "2.0.1"));
        #expect(matcher.evaluate(version: "3.0"));
        #expect(matcher.evaluate(version: "999.999.999"));
        #expect(matcher.evaluate(version: "3.0-SNAPSHOT"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "0.1-rc3"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]1.0,) ");
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "2.0"));
        #expect(matcher.evaluate(version: "2.0.1"));
        #expect(matcher.evaluate(version: "3.0"));
        #expect(matcher.evaluate(version: "999.999.999"));
        #expect(matcher.evaluate(version: "2.0-alpha01"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "1.0"));
        #expect(!matcher.evaluate(version: "1.0-alpha01"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " (,2.0]");
        #expect(matcher.evaluate(version: "0.0"));
        #expect(matcher.evaluate(version: "0.9.9"));
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "2.0"));
        #expect(matcher.evaluate(version: "2.0-beta3"));

        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "999.999.999"));
        #expect(!matcher.evaluate(version: "3.0-alpha01"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: " ( , 2.0 [ ");
        #expect(matcher.evaluate(version: "0.0"));
        #expect(matcher.evaluate(version: "0.9.9"));
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "1.1-rc1"));

        #expect(!matcher.evaluate(version: "2.0"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "999.999.999"));
        #expect(!matcher.evaluate(version: "3.0-beta33"));
    }

    @Test
    func exactConstraintIgnoresVersionQualifiers() throws {
        let matcher = try AirshipIvyVersionMatcher(versionConstraint: "1.0-beta");
        #expect(matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "1.0-alpha"));
        #expect(matcher.evaluate(version: "1.0-alpha01"));
        #expect(matcher.evaluate(version: "1.0-beta"));
        #expect(matcher.evaluate(version: "1.0-beta01"));
        #expect(matcher.evaluate(version: "1.0-rc"));
        #expect(matcher.evaluate(version: "1.0-rc1"));
        #expect(matcher.evaluate(version: "1.0"));

        #expect(!matcher.evaluate(version: "1.0.0-SNAPSHOT"));
        #expect(!matcher.evaluate(version: "1.0.0-alpha"));
        #expect(!matcher.evaluate(version: "1.0.0-alpha01"));
        #expect(!matcher.evaluate(version: "1.0.0-beta"));
        #expect(!matcher.evaluate(version: "1.0.0-beta01"));
        #expect(!matcher.evaluate(version: "1.0.0-rc"));
        #expect(!matcher.evaluate(version: "1.0.0-rc1"));
        #expect(!matcher.evaluate(version: "1.0.0"));
    }

    @Test
    func versionRangeIgnoresVersionQualifiers() throws {
        var matcher = try AirshipIvyVersionMatcher(versionConstraint: "[1.0-alpha, 2.0-alpha01]");
        #expect(matcher.evaluate(version: "1.0"));
        #expect(matcher.evaluate(version: "1.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "1.0.1"));
        #expect(matcher.evaluate(version: "1.5"));
        #expect(matcher.evaluate(version: "1.9.9"));
        #expect(matcher.evaluate(version: "1.9.9-rc1"));
        #expect(matcher.evaluate(version: "2.0-beta"));
        #expect(matcher.evaluate(version: "2.0"));

        #expect(!matcher.evaluate(version: "0.0"));
        #expect(!matcher.evaluate(version: "0.9.9"));
        #expect(!matcher.evaluate(version: "2.0.1"));
        #expect(!matcher.evaluate(version: "3.0"));
        #expect(!matcher.evaluate(version: "3.0-alpha"));

        matcher = try AirshipIvyVersionMatcher(versionConstraint: "]17.0.0-beta,)");
        #expect(!matcher.evaluate(version: "17.0.0"));
        #expect(!matcher.evaluate(version: "17.0.0-SNAPSHOT"));
        #expect(!matcher.evaluate(version: "17.0.0-alpha"));
        #expect(!matcher.evaluate(version: "17.0.0-beta"));
        #expect(!matcher.evaluate(version: "17.0.0-rc"));

        #expect(matcher.evaluate(version: "17.0.1"));
        #expect(matcher.evaluate(version: "17.0.1-SNAPSHOT"));
        #expect(matcher.evaluate(version: "17.0.1-alpha"));
        #expect(matcher.evaluate(version: "17.0.1-beta"));
        #expect(matcher.evaluate(version: "17.0.1-rc"));
        #expect(matcher.evaluate(version: "18.0.0"));
        #expect(matcher.evaluate(version: "18.0.0-SNAPSHOT"));
        #expect(matcher.evaluate(version: "18.0.0-alpha"));
        #expect(matcher.evaluate(version: "18.0.0-beta"));
        #expect(matcher.evaluate(version: "999.999.999"));
        #expect(matcher.evaluate(version: "999.999.999-rc"));
    }
}
