/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite
struct APNSEnvironmentTest {

    @Test
    func testProductionProfileParsing() throws {
        let profilePath = Bundle(for: APNSEnvironmentTestBundleLocator.self).path(
            forResource: "production-embedded",
            ofType: "mobileprovision"
        )

        let isProduction = try APNSEnvironment.isProduction(profilePath)
        #expect(isProduction)
    }

    @Test
    func testDevelopmentProfileParsing() throws {
        let profilePath = Bundle(for: APNSEnvironmentTestBundleLocator.self).path(
            forResource: "development-embedded",
            ofType: "mobileprovision"
        )

        let isProduction = try APNSEnvironment.isProduction(profilePath)
        #expect(!(isProduction))
    }

    @Test
    func testMissingEmbeddedProfile() {
        do {
            _ = try APNSEnvironment.isProduction(nil)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidEmbeddedProfilePath() {
        do {
            _ = try APNSEnvironment.isProduction("Neat")
            Issue.record("Should throw")
        } catch {}
    }

}

private final class APNSEnvironmentTestBundleLocator {}
