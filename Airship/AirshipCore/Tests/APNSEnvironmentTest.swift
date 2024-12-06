/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class APNSEnvironmentTest: XCTestCase {

    func testProductionProfileParsing() throws {
        let profilePath = Bundle(for: self.classForCoder).path(
            forResource: "production-embedded",
            ofType: "mobileprovision"
        )

        let isProduction = try APNSEnvironment.isProduction(profilePath)
        XCTAssertTrue(isProduction)
    }

    func testDevelopmentProfileParsing() throws {
        let profilePath = Bundle(for: self.classForCoder).path(
            forResource: "development-embedded",
            ofType: "mobileprovision"
        )

        let isProduction = try APNSEnvironment.isProduction(profilePath)
        XCTAssertFalse(isProduction)
    }

    func testMissingEmbeddedProfile() {
        do {
            _ = try APNSEnvironment.isProduction(nil)
            XCTFail()
        } catch {}
    }

    func testInvalidEmbeddedProfilePath() {
        do {
            _ = try APNSEnvironment.isProduction("Neat")
            XCTFail()
        } catch {}
    }

}
