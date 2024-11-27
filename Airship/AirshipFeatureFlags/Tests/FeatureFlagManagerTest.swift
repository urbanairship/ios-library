/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class AirshipFeatureFlagsTest: XCTestCase {

    private let remoteDataAccess: TestFeatureFlagRemoteDataAccess = TestFeatureFlagRemoteDataAccess()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()
    private let analytics: TestFeatureFlagAnalytics = TestFeatureFlagAnalytics()
    private let deviceInfoProvider: TestDeviceInfoProvider = TestDeviceInfoProvider()
    private let deferredResolver: TestFeatureFlagResolver = TestFeatureFlagResolver()
    private var privacyManager: AirshipPrivacyManager!
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    
    private var featureFlagManager: FeatureFlagManager!

    override func setUp() async throws {
        let config = RuntimeConfig(config: AirshipConfig(), dataStore: self.dataStore)
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: dataStore,
            config: config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
        self.featureFlagManager = FeatureFlagManager(
            dataStore: self.dataStore,
            remoteDataAccess: self.remoteDataAccess,
            analytics: self.analytics,
            audienceChecker: self.audienceChecker,
            deviceInfoProviderFactory: { self.deviceInfoProvider },
            deferredResolver: self.deferredResolver,
            privacyManager: self.privacyManager
        )
    }

    func testFlagAccessWaitsForRefreshIfOutOfDate() async throws {
        let expectation = XCTestExpectation()
        self.remoteDataAccess.waitForRefreshBlock = {
            expectation.fulfill()
        }
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(variables: nil)
                )
            )
        ]
        self.remoteDataAccess.status = .outOfDate
        let _ = try? await featureFlagManager.flag(name: "foo")
        await self.fulfillment(of: [expectation])
    }

    func testFlagAccessWaitsForRefreshIfFlagNotFound() async throws {
        let expectation = XCTestExpectation()
        self.remoteDataAccess.waitForRefreshBlock = {
            expectation.fulfill()
        }
        self.remoteDataAccess.status = .outOfDate
        let _ = try? await featureFlagManager.flag(name: "foo")
        await self.fulfillment(of: [expectation])
    }

    func testFlagAccessWaitsForRefreshIfStaleNotAllowed() async throws {
        let expectation = XCTestExpectation()
        self.remoteDataAccess.waitForRefreshBlock = {
            self.remoteDataAccess.status = .upToDate
            expectation.fulfill()
        }

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(variables: nil)
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: true)
            )
        ]

        self.remoteDataAccess.status = .stale
        let flag = try await featureFlagManager.flag(name: "foo")
        await self.fulfillment(of: [expectation])

        XCTAssertTrue(flag.exists)
    }

    func testNoFlags() async throws {
        self.remoteDataAccess.status = .upToDate
        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(name: "foo", isEligible: false, exists: false, variables: nil)
        XCTAssertEqual(expected, flag)
    }

    func testFlagNoAudience() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(variables: nil)
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        XCTAssertEqual(expected, flag)
    }

    func testFlagAudienceMatch() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(variables: nil)
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate,  _ in
            XCTAssertEqual(selector, flagInfo.audienceSelector)
            XCTAssertEqual(newUserDate, flagInfo.created)
            return true
        }
        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, flag)
    }

    func testFlagAudienceNoMatch() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(variables: nil)
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, flag)
    }

    func testAudienceMissLastInfoStatic() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting 1"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(variables: nil)
                )
            ),
            FeatureFlagInfo(
                id: "some other ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting 2"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(.string("some variables"))
                    )
                )
            ),

        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting 2"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, flag)
    }

    func testAudienceMissLastInfoDeferred() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting 1"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(variables: nil)
                )
            ),
            FeatureFlagInfo(
                id: "some other ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting 2"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            ),

        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting 2"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, flag)
    }

    func testMultipleFlags() async throws {
        let flagInfo1 = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(variables: nil)
            )
        )

        let flagInfo2 = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            audienceSelector: DeviceAudienceSelector(newUser: false),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .fixed(AirshipJSON.string("flagInfo2 variables"))
                )
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo1, flagInfo2
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            return selector == flagInfo2.audienceSelector
        }

        let flag = try await featureFlagManager.flag(name: "foo")

        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: AirshipJSON.string("flagInfo2 variables"),
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        XCTAssertEqual(expected, flag)
    }

    func testVariantVariables() async throws {
        let variables: [FeatureFlagVariables.VariablesVariant] = [
            FeatureFlagVariables.VariablesVariant(
                id: "variant 1",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("1")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant1 variables")
            ),
            FeatureFlagVariables.VariablesVariant(
                id: "variant 2",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("2")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant2 variables")
            ),
            FeatureFlagVariables.VariablesVariant(
                id: "variant 3",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("3")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant3 variables")
            )
        ]
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant(variables)
                )
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            // match second variant
            return selector == variables[1].audienceSelector
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: variables[1].data,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: variables[1].reportingMetadata,
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        XCTAssertEqual(expected, flag)
    }
    
    func testControlFlag() async throws {
        
        let controlAudience = DeviceAudienceSelector(
            versionPredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: .matcherWithVersionConstraint("1.6.0+")!
                )
            )
        )
        
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant([])
                )
            ),
            controlOptions: .init(
                audience: controlAudience,
                reportingMetadata: .string("supersede"),
                controlType: .flag)
        )
        
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]
        
        var audienceMatched = false
        self.audienceChecker.onEvaluate = { selector, _, _ in
            if selector == controlAudience {
                return audienceMatched
            }
            
            return true
        }
        
        let noControlFlag = try await featureFlagManager.flag(name: "foo")
        
        var expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        
        XCTAssertEqual(expected, noControlFlag)
        
        audienceMatched = true
        
        let controlFlag = try await featureFlagManager.flag(name: "foo")
        
        expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("supersede"),
                supersededReportingMetadata: [.string("reporting")],
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, controlFlag)
    }
    
    func testControlVariables() async throws {
        
        let controlAudience = DeviceAudienceSelector(
            versionPredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: .matcherWithVersionConstraint("1.6.0+")!
                )
            )
        )
        
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant([])
                )
            ),
            controlOptions: .init(
                audience: controlAudience,
                reportingMetadata: .string("supersede"),
                controlType: .variables(.string("variables-overrides")))
        )
        
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]
        
        var audienceMatched = false
        self.audienceChecker.onEvaluate = { selector, _, _ in
            if selector == controlAudience {
                return audienceMatched
            }
            
            return true
        }
        
        let noControlFlag = try await featureFlagManager.flag(name: "foo")
        
        var expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        
        XCTAssertEqual(expected, noControlFlag)
        
        audienceMatched = true
        
        let controlFlag = try await featureFlagManager.flag(name: "foo")
        
        expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: .string("variables-overrides"),
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("supersede"),
                supersededReportingMetadata: [.string("reporting")],
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        XCTAssertEqual(expected, controlFlag)
    }
    
    func testVariantVariablesDeferred() async throws {
        let variables: [FeatureFlagVariables.VariablesVariant] = [
            FeatureFlagVariables.VariablesVariant(
                id: "variant 1",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("1")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant1 variables")
            ),
            FeatureFlagVariables.VariablesVariant(
                id: "variant 2",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("2")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant2 variables")
            ),
            FeatureFlagVariables.VariablesVariant(
                id: "variant 3",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("3")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant3 variables")
            )
        ]
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: true, variables: .variant(variables), reportingMetadata: .string("reporting two"))
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: variables[1].data,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("Variant reporting"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            // match second variant
            return selector == variables[1].audienceSelector
        }

        await self.deferredResolver.setOnResolve { _, _ in
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(result, expectedFlag)
    }

    func testVariantVariablesDeferredNoMatch() async throws {
        let variables: [FeatureFlagVariables.VariablesVariant] = [
            FeatureFlagVariables.VariablesVariant(
                id: "variant 1",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("1")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant1 variables")
            ),
        ]
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: false, variables: .variant(variables), reportingMetadata: .string("reporting two"))
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting two"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            // match second variant
            return selector == variables[1].audienceSelector
        }

        await self.deferredResolver.setOnResolve { _, _ in
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(result, expectedFlag)
    }


    func testVariantVariablesNoMatch() async throws {
        let variables: [FeatureFlagVariables.VariablesVariant] = [
            FeatureFlagVariables.VariablesVariant(
                id: "variant 1",
                audienceSelector: DeviceAudienceSelector(tagSelector: .tag("1")),
                reportingMetadata: AirshipJSON.string("Variant reporting"),
                data: AirshipJSON.string("variant1 variables")
            )
        ]

        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting"),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant(variables)
                )
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: flagInfo.reportingMetadata,
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        XCTAssertEqual(expected, flag)
    }

    func testStaleNotDefined() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag,
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: .string("reporting"),
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    func testStaleAllowed() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: false)
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag,
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: .string("reporting"),
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    func testStaleNotAllowed() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: true)
            )
        ]

        do {
            let _ = try await featureFlagManager.flag(name: "foo")
            XCTFail("Should throw")
        } catch FeatureFlagError.staleData {
            // No-op
        } catch {
            XCTFail("Should throw staleData")
        }
    }

    func testStaleNotAllowedMultipleFlags() async throws {
        self.remoteDataAccess.status = .stale

        // If one flag does not allow we ignore all
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: false)
            ),
            FeatureFlagInfo(
                id: "some other ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: true)
            )
        ]

        do {
            let _ = try await featureFlagManager.flag(name: "foo")
            XCTFail("Should throw")
        }catch FeatureFlagError.staleData {
            // No-op
        } catch {
            XCTFail("Should throw staleData")
        }
    }

    func testOutOfDate() async throws {
        self.remoteDataAccess.status = .outOfDate

        do {
            let _ = try await featureFlagManager.flag(name: "foo")
            XCTFail("Should throw")
        } catch FeatureFlagError.outOfDate {
            // No-op
        } catch {
            XCTFail("Should throw outOfDate")
        }
    }

    func testMultipleFlagsNotEligible() async throws {
        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return false
        }

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting one"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            ),
            FeatureFlagInfo(
                id: "some other ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting two"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag,
            FeatureFlag(
                name: "foo",
                isEligible: false,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: .string("reporting two"),
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    func testTrackInteractive() async throws {
        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return false
        }

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting one"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            ),
            FeatureFlagInfo(
                id: "some other ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting two"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag,
            FeatureFlag(
                name: "foo",
                isEligible: false,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: .string("reporting two"),
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    func testTrackInteraction() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting two"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.featureFlagManager.trackInteraction(flag: flag)
        XCTAssertEqual(self.analytics.trackedInteractions, [flag])
    }

    func testDeferred() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting one"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: false, variables: nil, reportingMetadata: .string("reporting two"))
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting two"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return true
        }

        await self.deferredResolver.setOnResolve { [deviceInfoProvider] request, info in
            XCTAssertEqual(request.url, URL(string: "some-url://"))
            XCTAssertEqual(request.contactID, deviceInfoProvider.stableContactInfo.contactID)
            XCTAssertEqual(request.channelID, deviceInfoProvider.channelID)
            XCTAssertEqual(request.locale, deviceInfoProvider.locale)
            XCTAssertEqual(request.notificationOptIn, deviceInfoProvider.isUserOptedInPushNotifications)
            XCTAssertEqual(flagInfo, info)
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(result, expectedFlag)
    }

    func testDeferredLocalAudience() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting one"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return false
        }

        await self.deferredResolver.setOnResolve { _, _ in
            XCTFail()
            throw AirshipErrors.error("Failed")
        }

        let result = try await featureFlagManager.flag(name: "foo")
        XCTAssertFalse(result.isEligible)
    }

    func testMultipleDeferred() async throws {
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "one",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting one"),
                audienceSelector: DeviceAudienceSelector(newUser: false),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            ),
            FeatureFlagInfo(
                id: "two",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting two"),
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            ),
            FeatureFlagInfo(
                id: "three",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting three"),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            )
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return selector.newUser == true
        }

        await self.deferredResolver.setOnResolve { request, info in
            DeferredFlagResponse.found(
                DeferredFlag(
                    isEligible: info.id == "three",
                    variables: nil,
                    reportingMetadata: info.reportingMetadata
                )
            )
        }

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting three"),
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        let result = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(expectedFlag, result)

        let resolved = await self.deferredResolver.resolvedFlagInfos
        XCTAssertEqual(
            [
                self.remoteDataAccess.flagInfos[1],
                self.remoteDataAccess.flagInfos[2]
            ],
            resolved
        )
    }


    func testDeferredOutOfDate() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting one"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        self.remoteDataAccess.remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some://remote-data")!,
            lastModifiedTime: "last modified",
            source: .app
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return true
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw FeatureFlagEvaluationError.outOfDate
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            XCTAssertEqual(error as! FeatureFlagError, FeatureFlagError.outOfDate)
        }

        XCTAssertEqual(remoteDataAccess.lastOutdatedRemoteInfo, self.remoteDataAccess.remoteDataInfo)
    }

    func testDeferredConnectionIssue() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting one"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        self.remoteDataAccess.remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some://remote-data")!,
            lastModifiedTime: "last modified",
            source: .app
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return true
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw FeatureFlagEvaluationError.connectionError(errorMessage: "Failed to resolve flag.")
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            XCTAssertEqual(error as! FeatureFlagError, FeatureFlagError.connectionError(errorMessage: "Failed to resolve flag."))
        }

        XCTAssertNil(remoteDataAccess.lastOutdatedRemoteInfo)
    }

    func testDeferredOtherError() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: .string("reporting one"),
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        self.remoteDataAccess.remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some://remote-data")!,
            lastModifiedTime: "last modified",
            source: .app
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            return true
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw AirshipErrors.error("other!")
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            XCTAssertEqual(error as! FeatureFlagError, FeatureFlagError.failedToFetchData)
        }

        XCTAssertNil(remoteDataAccess.lastOutdatedRemoteInfo)
    }

}

final class TestFeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol, @unchecked Sendable {

    var lastOutdatedRemoteInfo: RemoteDataInfo?
    func remoteDataFlagInfo(name: String) async -> RemoteDataFeatureFlagInfo {
        let flags = flagInfos.filter { info in
            info.name == name
        }
        return RemoteDataFeatureFlagInfo(name: name, flagInfos: flags, remoteDataInfo: self.remoteDataInfo)
    }
    
    func notifyOutdated(remoteDateInfo: RemoteDataInfo?) async {
        lastOutdatedRemoteInfo = remoteDataInfo;
    }
    
    var waitForRefreshBlock: (() -> Void)?
    func waitForRefresh() async {
        self.waitForRefreshBlock?()
    }
    
    var status: RemoteDataSourceStatus = .upToDate
    var flagInfos: [FeatureFlagInfo] = []
    var remoteDataInfo: RemoteDataInfo?

}


final class TestFeatureFlagAnalytics: FeatureFlagAnalyticsProtocol, @unchecked Sendable {
    func trackInteraction(flag: FeatureFlag) {
        trackedInteractions.append(flag)
    }

    var trackedInteractions: [FeatureFlag] = []
}


final class TestDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    var sdkVersion: String = "1.0.0"


    var isAirshipReady: Bool = false

    var tags: Set<String> = Set()

    var isChannelCreated: Bool = true

    var channelID: String = UUID().uuidString

    var locale: Locale = Locale.current

    var appVersion: String?
    
    var permissions: [AirshipCore.AirshipPermission : AirshipCore.AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactInfo: StableContactInfo = StableContactInfo(contactID: UUID().uuidString)

}


final actor TestFeatureFlagResolver: FeatureFlagDeferredResolverProtocol {

    var resolvedFlagInfos: [FeatureFlagInfo] = []

    var onResolve: ((DeferredRequest, FeatureFlagInfo) async throws -> DeferredFlagResponse)?

    func setOnResolve(onResolve: @escaping @Sendable (DeferredRequest, FeatureFlagInfo) async throws -> DeferredFlagResponse) {
        self.onResolve = onResolve
    }

    func resolve(request: DeferredRequest, flagInfo: FeatureFlagInfo) async throws -> DeferredFlagResponse {
        resolvedFlagInfos.append(flagInfo)
        return try await self.onResolve!(request, flagInfo)
    }
}
