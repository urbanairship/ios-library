/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AirshipConfigTest: XCTestCase {

    func testURLAllowListNotSetAfterCopy() throws {
        let config = AirshipConfig()
        let copy = config.copy() as! AirshipConfig
        XCTAssertFalse(copy.isURLAllowListSet)
        XCTAssertFalse(copy.isURLAllowListScopeOpenURLSet)
    }
    
    func testURLAllowListSetAfterCopy() throws {
        let config = AirshipConfig()
        config.urlAllowList = ["neat"]

        let copy = config.copy() as! AirshipConfig
        XCTAssertTrue(copy.isURLAllowListSet)
    }

    func testURLAllowScopeOpenURLSetListSetAfterCopy() throws {
        let config = AirshipConfig()
        config.urlAllowListScopeOpenURL = ["neat"]

        let copy = config.copy() as! AirshipConfig
        XCTAssertTrue(copy.isURLAllowListScopeOpenURLSet)
    }
    
    func testUnknownKeyHandling() {
        let config = AirshipConfig()
        XCTAssertNoThrow(config.setValue("someValue", forKey: "thisKeyDoesNotExist"))
    }
    
    func testProductionProfileParsing() {
        let profilePath = Bundle(for: self.classForCoder).path(forResource: "production-embedded", ofType: "mobileprovision")!
        XCTAssert(AirshipConfig.isProductionProvisioningProfile(profilePath))
    }
    
    func testDevelopmentProfileParsing() {
        let profilePath = Bundle(for: self.classForCoder).path(
            forResource: "development-embedded",
            ofType: "mobileprovision"
        )!

        XCTAssertFalse(AirshipConfig.isProductionProvisioningProfile(profilePath))
    }
    
    func testMissingEmbeddedProfile() {
        XCTAssertTrue(AirshipConfig.isProductionProvisioningProfile(""))
    }
    
    func testSimulatorFallback() {
        // Ensure that the simulator falls back to the inProduction flag as it was set if there isn't a profile
        let production = AirshipConfig()
        production.profilePath = nil
        production.inProduction = true
        production.detectProvisioningMode = true
        XCTAssertTrue(production.inProduction)

        let development = AirshipConfig()
        development.profilePath = nil
        development.inProduction = false
        development.detectProvisioningMode = true
        XCTAssertFalse(development.inProduction)
    }
    
    func testMissingProvisioningOnDeviceFallback() {
        // Ensure that a device falls back to YES rather than inProduction when there isn't a profile
        let config = AirshipConfig()
        config.profilePath = nil
        config.inProduction = false
        config.detectProvisioningMode = true
        XCTAssertFalse(config.inProduction, "Devices without embedded provisioning profiles AND provisioning detection enabled should return YES for inProduction as a safety measure.")
    }
    
    func testProductionFlag() {
        let config = AirshipConfig()
        
        // initialize with a custom profile path that is accessible from this test environment
        config.profilePath = Bundle(for: self.classForCoder).path(forResource: "production-embedded", ofType: "mobileprovision")!
        
        // populate dev and prod keys, then toggle between them
        config.developmentAppKey = "devAppKey"
        config.developmentAppSecret = "devAppSecret"
        config.developmentLogLevel = .verbose //not the default
        
        config.productionAppKey = "prodAppKey"
        config.productionAppSecret = "prodAppSecret"
        config.productionLogLevel = .none //not the default

        XCTAssertTrue(config.inProduction, "inProduction defaults to YES.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode defaults to YES.")
        XCTAssertEqual(config.appKey, config.productionAppKey, "Incorrect app key resolution.")
        XCTAssertEqual(config.appSecret, config.productionAppSecret, "Incorrect app secret resolution.")
        XCTAssertEqual(config.logLevel, config.productionLogLevel, "Incorrect log level resolution.")
        XCTAssertEqual(config.logPrivacyLevel, config.productionLogPrivacyLevel, "Incorrect log privacy level resolution.")

        config.inProduction = false
        XCTAssertFalse(config.detectProvisioningMode, "detectProvisioningMode defaults to NO.")
        XCTAssertEqual(config.appKey, config.developmentAppKey, "Incorrect app key resolution.")
        XCTAssertEqual(config.appSecret, config.developmentAppSecret, "Incorrect app secret resolution.")
        XCTAssertEqual(config.logLevel, config.developmentLogLevel, "Incorrect log level resolution.")
        XCTAssertEqual(config.logPrivacyLevel, config.developmentLogPrivacyLevel, "Incorrect log privacy level resolution.")

        config.inProduction = true
        XCTAssertFalse(config.detectProvisioningMode, "detectProvisioningMode defaults to NO.")
        XCTAssertEqual(config.appKey, config.productionAppKey, "Incorrect app key resolution.")
        XCTAssertEqual(config.appSecret, config.productionAppSecret, "Incorrect app secret resolution.")
        XCTAssertEqual(config.logLevel, config.productionLogLevel, "Incorrect log level resolution.")
        XCTAssertEqual(config.logPrivacyLevel, config.productionLogPrivacyLevel, "Incorrect log privacy level resolution.")

        config.detectProvisioningMode = true
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode defaults to YES.")
        XCTAssertTrue(config.inProduction, "The embedded provisioning profile is a production profile.")
    }
    
    /**
     * Test detectProvisioningMode = true when neither detectProvisioningMode or inProduction
     * is explicity set in AirshipConfig.plist
     */
    func testDetectProvisioningModeDefault() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Without-InProduction-And-DetectProvisioningMode", ofType: "plist")!
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "AirshipConfig (modern) File is invalid.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode should default to true")
    }
    
    /**
     * Test detectProvisioningMode = true when detectProvisioningMode is explicity set in AirshipConfig.plist
     */
    func testDetectProvisioningModeExplicitlySet() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-DetectProvisioningMode", ofType: "plist")!
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "AirshipConfig (modern) File is invalid.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode should default to true")
    }
    
    /**
     * Test inProduction = true when inProduction is explicitly set in AirshipConfig.plist
     */
    func testInProductionExplicitlySet() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-InProduction", ofType: "plist")!
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "AirshipConfig (modern) File is invalid.")
        XCTAssertTrue(config.inProduction, "inProduction should be true")
    }
    
    /**
     * Test when both detectProvisioningMode and inProduction is explicitly set in AirshipConfig.plist
     */
    func testDetectProvisioningModeAndInProductionExplicitlySet() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid", ofType: "plist")!
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "AirshipConfig (modern) File is invalid.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode should be true")
        XCTAssertTrue(config.inProduction, "inProduction should be true")
        XCTAssertEqual(CloudSite.eu, config.site)
        XCTAssertEqual("https://some-chat-url", config.chatURL)
        XCTAssertEqual(["*"], config.urlAllowListScopeOpenURL)
    }
    
    func testOldPlistFormat() {
        let legacyPlist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid-Legacy-NeXTStep", ofType: "plist")!
        let validAppValue = "0A00000000000000000000"
        let config = AirshipConfig(contentsOfFile: legacyPlist)
        
        XCTAssertTrue(config.validate(), "Legacy Config File is invalid.")

        XCTAssertEqual(config.productionAppKey, validAppValue, "Production app key was improperly loaded.")
        XCTAssertEqual(config.productionAppSecret, validAppValue, "Production app secret was improperly loaded.")
        XCTAssertEqual(config.developmentAppKey, validAppValue, "Development app key was improperly loaded.")
        XCTAssertEqual(config.developmentAppSecret, validAppValue, "Development app secret was improperly loaded.")

        XCTAssertEqual(config.developmentLogLevel, .verbose, "Development log level was improperly loaded.")
        XCTAssertTrue(config.inProduction, "inProduction was improperly loaded.")
    }
    
    func testPlistParsing() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid", ofType: "plist")!
        let validAppValue = "0A00000000000000000000"
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "AirshipConfig (modern) File is invalid.")

        XCTAssertEqual(config.productionAppKey, validAppValue, "Production app key was improperly loaded.")
        XCTAssertEqual(config.productionAppSecret, validAppValue, "Production app secret was improperly loaded.")
        XCTAssertEqual(config.developmentAppKey, validAppValue, "Development app key was improperly loaded.")
        XCTAssertEqual(config.developmentAppSecret, validAppValue, "Development app secret was improperly loaded.")

        XCTAssertEqual(config.developmentLogLevel, .error, "Development log level was improperly loaded.")
        XCTAssertEqual(config.productionLogLevel, .verbose, "Production log level was improperly loaded.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode was improperly loaded.")
        XCTAssertTrue(config.isChannelCreationDelayEnabled, "channelCreationDelayEnabled was improperly loaded.")
        XCTAssertTrue(config.isExtendedBroadcastsEnabled, "extendedBroadcastsEnabled was improperly loaded.")

        //special case this one since we have to disable detectProvisioningMode
        config.detectProvisioningMode = false
        XCTAssertTrue(config.inProduction, "inProduction was improperly loaded.")
        
        XCTAssert(config.enabledFeatures.contains(.push))
        XCTAssert(config.enabledFeatures.contains(.inAppAutomation))

        XCTAssertTrue(config.resetEnabledFeatures, "resetEnabledFeatures was improperly loaded.")
    }
    
    func testNeXTStepPlistParsing() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid-NeXTStep", ofType: "plist")!
        let validAppValue = "0A00000000000000000000"
        let config = AirshipConfig(contentsOfFile: plist)
        
        XCTAssertTrue(config.validate(), "NeXTStep plist file is invalid.")

        XCTAssertEqual(config.productionAppKey, validAppValue, "Production app key was improperly loaded.")
        XCTAssertEqual(config.productionAppSecret, validAppValue, "Production app secret was improperly loaded.")
        XCTAssertEqual(config.developmentAppKey, validAppValue, "Development app key was improperly loaded.")
        XCTAssertEqual(config.developmentAppSecret, validAppValue, "Development app secret was improperly loaded.")

        XCTAssertEqual(config.developmentLogLevel, .error, "Development log level was improperly loaded.")
        XCTAssertEqual(config.productionLogLevel, .verbose, "Production log level was improperly loaded.")
        XCTAssertTrue(config.detectProvisioningMode, "detectProvisioningMode was improperly loaded.")
        XCTAssertTrue(config.isChannelCreationDelayEnabled, "channelCreationDelayEnabled was improperly loaded.")

        //special case this one since we have to disable detectProvisioningMode
        config.detectProvisioningMode = false
        XCTAssertTrue(config.inProduction, "inProduction was improperly loaded.")
    }
    
    func testValidation() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid", ofType: "plist")!
        let validAppValue = "0A00000000000000000000"
        let invalidValue = " invalid!!! "
        let config = AirshipConfig(contentsOfFile: plist)
        
        config.inProduction = false
        config.detectProvisioningMode = false

        // Make it invalid and then valid again, asserting the whole way.
        
        config.developmentAppKey = invalidValue
        XCTAssertFalse(config.validate(), "Development App Key is improperly verified.")
        config.developmentAppKey = validAppValue

        config.developmentAppSecret = invalidValue
        XCTAssertFalse(config.validate(), "Development App Secret is improperly verified.")
        config.developmentAppSecret = validAppValue

        //switch to production mode as validation only strictly checks the current keypair
        config.inProduction = true

        config.productionAppKey = invalidValue
        XCTAssertFalse(config.validate(), "Production App Key is improperly verified.")
        config.productionAppKey = validAppValue

        config.productionAppSecret = invalidValue
        XCTAssertFalse(config.validate(), "Production App Secret is improperly verified.")
        config.productionAppSecret = validAppValue
    }
    
    func testCopyConfig() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "AirshipConfig-Valid", ofType: "plist")!
        let config = AirshipConfig(contentsOfFile: plist)
        let copy = config.copy() as! AirshipConfig
        
        XCTAssertEqual(copy.description, config.description)
        XCTAssertTrue(copy.developmentAppKey == config.developmentAppKey)
        XCTAssertTrue(copy.developmentAppSecret == config.developmentAppSecret)
        XCTAssertTrue(copy.productionAppKey == config.productionAppKey)
        XCTAssertTrue(copy.productionAppSecret == config.productionAppSecret)
        XCTAssertTrue(copy.deviceAPIURL == config.deviceAPIURL)
        XCTAssertTrue(copy.remoteDataAPIURL == config.remoteDataAPIURL)
        XCTAssertTrue(copy.analyticsURL == config.analyticsURL)
        XCTAssertTrue(copy.developmentLogLevel == config.developmentLogLevel)
        XCTAssertTrue(copy.developmentLogPrivacyLevel == config.developmentLogPrivacyLevel)
        XCTAssertTrue(copy.productionLogLevel == config.productionLogLevel)
        XCTAssertTrue(copy.productionLogPrivacyLevel == config.productionLogPrivacyLevel)
        XCTAssertTrue(copy.inProduction == config.inProduction)
        XCTAssertTrue(copy.detectProvisioningMode == config.detectProvisioningMode)
        XCTAssertTrue(copy.profilePath == config.profilePath)
        XCTAssertTrue(copy.isAnalyticsEnabled == config.isAnalyticsEnabled)
        XCTAssertTrue(copy.clearUserOnAppRestore == config.clearUserOnAppRestore)
        XCTAssertEqual(copy.urlAllowList, config.urlAllowList)
        XCTAssertEqual(copy.urlAllowListScopeJavaScriptInterface, config.urlAllowListScopeJavaScriptInterface)
        XCTAssertEqual(copy.urlAllowListScopeOpenURL, config.urlAllowListScopeOpenURL)
        XCTAssertTrue(copy.clearNamedUserOnAppRestore == config.clearNamedUserOnAppRestore)
        XCTAssertTrue(copy.isChannelCaptureEnabled == config.isChannelCaptureEnabled)
        XCTAssertTrue(copy.isChannelCreationDelayEnabled == config.isChannelCreationDelayEnabled)
        XCTAssertTrue(copy.isExtendedBroadcastsEnabled == config.isExtendedBroadcastsEnabled)
        XCTAssertTrue(copy.messageCenterStyleConfig == config.messageCenterStyleConfig)
        XCTAssertTrue(copy.itunesID == config.itunesID)
        XCTAssertTrue(copy.requestAuthorizationToUseNotifications == config.requestAuthorizationToUseNotifications)
        XCTAssertTrue(copy.requireInitialRemoteConfigEnabled == config.requireInitialRemoteConfigEnabled)
        XCTAssertTrue(copy.resetEnabledFeatures == config.resetEnabledFeatures)

        XCTAssertEqual(copy.enabledFeatures, config.enabledFeatures)
    }
    
    func testInitialConfig() {
        let config = AirshipConfig()
        
        XCTAssertEqual(CloudSite.us, config.site)
        XCTAssertNil(config.deviceAPIURL)
        XCTAssertNil(config.remoteDataAPIURL)
        XCTAssertNil(config.analyticsURL)
        XCTAssertEqual(config.developmentLogLevel, .debug)
        XCTAssertEqual(config.developmentLogPrivacyLevel, .private)
        XCTAssertEqual(config.productionLogLevel, .error)
        XCTAssertEqual(config.productionLogPrivacyLevel, .private)
        XCTAssertFalse(config.inProduction)
        XCTAssertTrue(config.detectProvisioningMode)
        XCTAssertTrue(config.isAutomaticSetupEnabled)
        XCTAssertTrue(config.isAnalyticsEnabled)
        XCTAssertFalse(config.clearUserOnAppRestore)
        XCTAssertEqual(config.urlAllowList.count, 0)
        XCTAssertEqual(config.urlAllowListScopeJavaScriptInterface.count, 0)
        XCTAssertEqual(config.urlAllowListScopeOpenURL.count, 0)
        XCTAssertFalse(config.clearNamedUserOnAppRestore)
        XCTAssertTrue(config.isChannelCaptureEnabled)
        XCTAssertFalse(config.isChannelCreationDelayEnabled)
        XCTAssertFalse(config.isExtendedBroadcastsEnabled)
        XCTAssertTrue(config.requestAuthorizationToUseNotifications)
        XCTAssertTrue(config.requireInitialRemoteConfigEnabled)
        XCTAssertFalse(config.resetEnabledFeatures)
    }
}
