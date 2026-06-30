/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite
struct AirshipConfigTest {
    @Test
    func testEmptyConfig() {
        let config = AirshipConfig()
        verifyDefaultConfig(config)
    }

    @Test
    func testConfigFromEmptyJSON() throws {
        let config: AirshipConfig = try AirshipJSON.wrap([:]).decode()
        verifyDefaultConfig(config)
    }

    @Test
    func testOldPlistFormat() throws {
        let path = Bundle(for: AirshipConfigTestBundleLocator.self).path(
            forResource: "AirshipConfig-Valid-Legacy",
            ofType: "plist"
        )
        let config = try AirshipConfig(fromPlist: path!)
        #expect(config.productionAppKey == "0A00000000000000000000")
        #expect(config.productionAppSecret == "0A00000000000000000000")
        #expect(config.developmentAppKey == "0A00000000000000000000")
        #expect(config.developmentAppSecret == "0A00000000000000000000")
        #expect(config.developmentLogLevel == .verbose)
        #expect(config.inProduction == true)
    }

    @Test
    func testPlistParsing() throws {
        let path = Bundle(for: AirshipConfigTestBundleLocator.self).path(
            forResource: "AirshipConfig-Valid",
            ofType: "plist"
        )

        let config = try AirshipConfig(fromPlist: path!)
        #expect(config.productionAppKey == "0A00000000000000000000")
        #expect(config.productionAppSecret == "0A00000000000000000000")
        #expect(config.developmentAppKey == "0A00000000000000000000")
        #expect(config.developmentAppSecret == "0A00000000000000000000")
        #expect(config.developmentLogLevel == .error)
        #expect(config.developmentLogPrivacyLevel == .private)
        #expect(config.productionLogLevel == .verbose)
        #expect(config.productionLogPrivacyLevel == .public)
        #expect(config.isChannelCreationDelayEnabled)
        #expect(config.isExtendedBroadcastsEnabled)
        #expect(config.inProduction == true)
        #expect(config.enabledFeatures == [.inAppAutomation, .push])
        #expect(config.resetEnabledFeatures)
        #expect(config.messageCenterStyleConfig == "ValidUAMessageCenterDefaultStyle")
    }

    private func verifyDefaultConfig(
        _ config: AirshipConfig
    ) {
        #expect(config.developmentAppKey == nil)
        #expect(config.developmentAppSecret == nil)
        #expect(config.productionAppKey == nil)
        #expect(config.productionAppSecret == nil)
        #expect(config.defaultAppKey == nil)
        #expect(config.defaultAppSecret == nil)
        #expect(config.logHandler == nil)
        #expect(config.site == .us)
        #expect(config.developmentLogLevel == .debug)
        #expect(config.developmentLogPrivacyLevel == .private)
        #expect(config.productionLogLevel == .error)
        #expect(config.productionLogPrivacyLevel == .private)
        #expect(config.inProduction == nil)
        #expect(config.isAutomaticSetupEnabled)
        #expect(config.isAnalyticsEnabled)
        #expect(!(config.clearUserOnAppRestore))
        #expect(config.urlAllowList == nil)
        #expect(config.urlAllowListScopeJavaScriptInterface == nil)
        #expect(config.urlAllowListScopeOpenURL == nil)
        #expect(!(config.clearNamedUserOnAppRestore))
        #expect(config.isChannelCaptureEnabled)
        #expect(!(config.isChannelCreationDelayEnabled))
        #expect(!(config.isExtendedBroadcastsEnabled))
        #expect(config.requestAuthorizationToUseNotifications)
        #expect(config.requireInitialRemoteConfigEnabled)
        #expect(!(config.autoPauseInAppAutomationOnLaunch))
        #expect(!(config.resetEnabledFeatures))
        #expect(!(config.isWebViewInspectionEnabled))
        #expect(config.connectionChallengeResolver == nil)
        #expect(config.restoreChannelID == nil)
        #expect(config.itunesID == nil)
        #expect(config.messageCenterStyleConfig == nil)
        #expect(config.enabledFeatures == .all)
        #expect(config.initialConfigURL == nil)
        #expect(!(config.useUserPreferredLocale))
        #expect(config.restoreMessageCenterOnReinstall)
    }

    @Test
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
        block: () throws -> Void
    ) {
        do {
            try block()
            Issue.record("Should throw")
        } catch {}
    }
}

private final class AirshipConfigTestBundleLocator {}
