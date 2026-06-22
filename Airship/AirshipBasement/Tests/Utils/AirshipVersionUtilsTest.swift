/* Copyright Airship and Contributors */

import XCTest

@_spi(AirshipInternal) @testable import AirshipBasement

final class AirshipVersionUtilsTest: XCTestCase {

    func testEqualVersions() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.0"), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("2.3.4", toVersion: "2.3.4"), .orderedSame)
    }

    func testAscending() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "2.0.0"), .orderedAscending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.1.0"), .orderedAscending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.1"), .orderedAscending)
    }

    func testDescending() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("2.0.0", toVersion: "1.0.0"), .orderedDescending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.0.0"), .orderedDescending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0.0"), .orderedDescending)
    }

    func testDifferentLengths() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0", toVersion: "1.0.0"), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1", toVersion: "1.0.0"), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0"), .orderedDescending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0", toVersion: "1.0.1"), .orderedAscending)
    }

    func testMaxVersionParts() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0.2", maxVersionParts: 2), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.2.0", maxVersionParts: 1), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.2.0", maxVersionParts: 2), .orderedAscending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.0", maxVersionParts: 0), .orderedSame)
    }

    func testLongVersions() {
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.22.6.189", toVersion: "1.22.6.190"), .orderedAscending)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.22.6.189", toVersion: "1.22.6.189"), .orderedSame)
        XCTAssertEqual(AirshipVersionUtils.compareVersions("1.22.7.0", toVersion: "1.22.6.999"), .orderedDescending)
    }
}
