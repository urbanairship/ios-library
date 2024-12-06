/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AirshipConfigTest: XCTestCase {
    func testEmptyConfig() {
        let config = AirshipConfig()
        verifyDefaultConfig(config)
    }

    func testConfigFromEmptyJSON() throws {
        let config: AirshipConfig = try AirshipJSON.wrap([:]).decode()
        verifyDefaultConfig(config)
    }

    func testOldPlistFormat() throws {
        let path = Bundle(for: self.classForCoder).path(
            forResource: "AirshipConfig-Valid-Legacy",
            ofType: "plist"
        )
        let config = try AirshipConfig(fromPlist: path!)
        XCTAssertEqual(config.productionAppKey, "0A00000000000000000000")
        XCTAssertEqual(config.productionAppSecret, "0A00000000000000000000")
        XCTAssertEqual(config.developmentAppKey, "0A00000000000000000000")
        XCTAssertEqual(config.developmentAppSecret, "0A00000000000000000000")
        XCTAssertEqual(config.developmentLogLevel, .verbose)
        XCTAssertEqual(config.inProduction, true)
    }

    func testPlistParsing() throws {
        let path = Bundle(for: self.classForCoder).path(
            forResource: "AirshipConfig-Valid",
            ofType: "plist"
        )

        let config = try AirshipConfig(fromPlist: path!)
        XCTAssertEqual(config.productionAppKey, "0A00000000000000000000")
        XCTAssertEqual(config.productionAppSecret, "0A00000000000000000000")
        XCTAssertEqual(config.developmentAppKey, "0A00000000000000000000")
        XCTAssertEqual(config.developmentAppSecret, "0A00000000000000000000")
        XCTAssertEqual(config.developmentLogLevel, .error)
        XCTAssertEqual(config.developmentLogPrivacyLevel, .private)
        XCTAssertEqual(config.productionLogLevel, .verbose)
        XCTAssertEqual(config.productionLogPrivacyLevel, .public)
        XCTAssertTrue(config.isChannelCreationDelayEnabled)
        XCTAssertTrue(config.isExtendedBroadcastsEnabled)
        XCTAssertEqual(config.inProduction, true)
        XCTAssertEqual(config.enabledFeatures, [.inAppAutomation, .push])
        XCTAssertTrue(config.resetEnabledFeatures)
        XCTAssertEqual(config.messageCenterStyleConfig, "ValidUAMessageCenterDefaultStyle")
    }

    private func verifyDefaultConfig(
        _ config: AirshipConfig,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(config.developmentAppKey)
        XCTAssertNil(config.developmentAppSecret)
        XCTAssertNil(config.productionAppKey)
        XCTAssertNil(config.productionAppSecret)
        XCTAssertNil(config.defaultAppKey)
        XCTAssertNil(config.defaultAppSecret)
        XCTAssertNil(config.logHandler)
        XCTAssertEqual(config.site, .us)
        XCTAssertEqual(config.developmentLogLevel, .debug)
        XCTAssertEqual(config.developmentLogPrivacyLevel, .private)
        XCTAssertEqual(config.productionLogLevel, .error)
        XCTAssertEqual(config.productionLogPrivacyLevel, .private)
        XCTAssertNil(config.inProduction)
        XCTAssertTrue(config.isAutomaticSetupEnabled)
        XCTAssertTrue(config.isAnalyticsEnabled)
        XCTAssertFalse(config.clearUserOnAppRestore)
        XCTAssertNil(config.urlAllowList)
        XCTAssertNil(config.urlAllowListScopeJavaScriptInterface)
        XCTAssertNil(config.urlAllowListScopeOpenURL)
        XCTAssertFalse(config.clearNamedUserOnAppRestore)
        XCTAssertTrue(config.isChannelCaptureEnabled)
        XCTAssertFalse(config.isChannelCreationDelayEnabled)
        XCTAssertFalse(config.isExtendedBroadcastsEnabled)
        XCTAssertTrue(config.requestAuthorizationToUseNotifications)
        XCTAssertTrue(config.requireInitialRemoteConfigEnabled)
        XCTAssertFalse(config.autoPauseInAppAutomationOnLaunch)
        XCTAssertFalse(config.resetEnabledFeatures)
        XCTAssertFalse(config.isWebViewInspectionEnabled)
        XCTAssertNil(config.connectionChallengeResolver)
        XCTAssertNil(config.restoreChannelID)
        XCTAssertNil(config.itunesID)
        XCTAssertNil(config.messageCenterStyleConfig)
        XCTAssertEqual(config.enabledFeatures, .all)
        XCTAssertNil(config.initialConfigURL)
        XCTAssertFalse(config.useUserPreferredLocale)
        XCTAssertTrue(config.restoreMessageCenterOnReinstall)
    }

    func testValidation() throws {
        var config = AirshipConfig()

        // Not set
        verifyThrows {
            try config.validateCredentials(inProduction: true)
        }
        verifyThrows {
            try config.validateCredentials(inProduction: false)
        }

        // App key & secret match
        config.developmentAppKey = "0A00000000000000000000"
        config.developmentAppSecret = "0A00000000000000000000"
        verifyThrows {
            try config.validateCredentials(inProduction: false)
        }

        // Should not throw
        config.developmentAppSecret = "0B00000000000000000000"
        try config.validateCredentials(inProduction: false)

        // Production still not set
        verifyThrows {
            try config.validateCredentials(inProduction: true)
        }

        // Invalid key
        config.productionAppKey = "NOT VALID"
        config.productionAppSecret = "0A00000000000000000000"
        verifyThrows {
            try config.validateCredentials(inProduction: true)
        }

        // Invalid secret
        config.productionAppKey = "0A00000000000000000000"
        config.productionAppSecret = "NOT VALID"
        verifyThrows {
            try config.validateCredentials(inProduction: true)
        }

        // Both invalid
        config.productionAppKey = "NOT VALID KEY"
        config.productionAppSecret = "NOT VALID"
        verifyThrows {
            try config.validateCredentials(inProduction: true)
        }

        // Both valid
        config.productionAppKey = "0A00000000000000000000"
        config.productionAppSecret = "0B00000000000000000000"
        try config.validateCredentials(inProduction: true)
    }

    private func verifyThrows(
        block: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try block()
            XCTFail()
        } catch {}
    }
}
