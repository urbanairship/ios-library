/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) @testable import AirshipBasement

struct AirshipVersionUtilsTest {

    @Test
    func equalVersions() {
        #expect(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.0") == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("2.3.4", toVersion: "2.3.4") == .orderedSame)
    }

    @Test
    func ascending() {
        #expect(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "2.0.0") == .orderedAscending)
        #expect(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.1.0") == .orderedAscending)
        #expect(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.1") == .orderedAscending)
    }

    @Test
    func descending() {
        #expect(AirshipVersionUtils.compareVersions("2.0.0", toVersion: "1.0.0") == .orderedDescending)
        #expect(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.0.0") == .orderedDescending)
        #expect(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0.0") == .orderedDescending)
    }

    @Test
    func differentLengths() {
        #expect(AirshipVersionUtils.compareVersions("1.0", toVersion: "1.0.0") == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("1", toVersion: "1.0.0") == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0") == .orderedDescending)
        #expect(AirshipVersionUtils.compareVersions("1.0", toVersion: "1.0.1") == .orderedAscending)
    }

    @Test
    func maxVersionParts() {
        #expect(AirshipVersionUtils.compareVersions("1.0.1", toVersion: "1.0.2", maxVersionParts: 2) == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.2.0", maxVersionParts: 1) == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("1.1.0", toVersion: "1.2.0", maxVersionParts: 2) == .orderedAscending)
        #expect(AirshipVersionUtils.compareVersions("1.0.0", toVersion: "1.0.0", maxVersionParts: 0) == .orderedSame)
    }

    @Test
    func longVersions() {
        #expect(AirshipVersionUtils.compareVersions("1.22.6.189", toVersion: "1.22.6.190") == .orderedAscending)
        #expect(AirshipVersionUtils.compareVersions("1.22.6.189", toVersion: "1.22.6.189") == .orderedSame)
        #expect(AirshipVersionUtils.compareVersions("1.22.7.0", toVersion: "1.22.6.999") == .orderedDescending)
    }
}
