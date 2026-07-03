/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

struct AirshipFeatureFlagsTest {

    private let remoteDataAccess: TestFeatureFlagRemoteDataAccess = TestFeatureFlagRemoteDataAccess()
    private let remoteData: TestRemoteData = TestRemoteData()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()
    private let analytics: TestFeatureFlagAnalytics = TestFeatureFlagAnalytics()
    private let deviceInfoProvider: TestDeviceInfoProvider = TestDeviceInfoProvider()
    private let deferredResolver: TestFeatureFlagResolver = TestFeatureFlagResolver()
    private let privacyManager: TestPrivacyManager
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    private let resultCache: DefaultFeatureFlagResultCache = DefaultFeatureFlagResultCache(cache: TestCache())

    private let featureFlagManager: DefaultFeatureFlagManager

    init() async throws {
        let config: RuntimeConfig = .testConfig()
        self.privacyManager = TestPrivacyManager(
            dataStore: dataStore,
            config: config,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
        self.featureFlagManager = DefaultFeatureFlagManager(
            dataStore: self.dataStore,
            remoteDataAccess: self.remoteDataAccess,
            remoteData: self.remoteData,
            analytics: self.analytics,
            audienceChecker: self.audienceChecker,
            deviceInfoProviderFactory: { [provider = self.deviceInfoProvider] in provider },
            deferredResolver: self.deferredResolver,
            privacyManager: self.privacyManager,
            resultCache: self.resultCache
        )
    }

    @Test
    func testFlagAccessWaitsForRefreshIfOutOfDateAndStaleNotAllowed() async throws {
        await confirmation { confirmation in
            self.remoteDataAccess.bestEffortRefresh = {
                confirmation()
            }
            self.remoteDataAccess.flagInfos = [
                FeatureFlagInfo(
                    id: "some ID",
                    created: Date(),
                    lastUpdated: Date(),
                    name: "foo",
                    reportingMetadata: "reporting",
                    flagPayload: .staticPayload(
                        FeatureFlagPayload.StaticInfo(variables: nil)
                    ),
                    evaluationOptions: EvaluationOptions(disallowStaleValue: true)
                )
            ]
            self.remoteDataAccess.status = .outOfDate
            let _ = try? await featureFlagManager.flag(name: "foo")
        }
    }

    @Test
    func testFlagAccessWaitsForRefreshIfFlagNotFound() async throws {
        await confirmation { confirmation in
            self.remoteDataAccess.bestEffortRefresh = {
                confirmation()
            }
            self.remoteDataAccess.status = .outOfDate
            let _ = try? await featureFlagManager.flag(name: "foo")
        }
    }

    @Test
    func testFlagAccessWaitsForRefreshIfStaleNotAllowed() async throws {
        let flag = try await confirmation { confirmation in
            self.remoteDataAccess.bestEffortRefresh = {
                self.remoteDataAccess.status = .upToDate
                confirmation()
            }

            self.remoteDataAccess.flagInfos = [
                FeatureFlagInfo(
                    id: "some ID",
                    created: Date(),
                    lastUpdated: Date(),
                    name: "foo",
                    reportingMetadata: "reporting",
                    flagPayload: .staticPayload(
                        FeatureFlagPayload.StaticInfo(variables: nil)
                    ),
                    evaluationOptions: EvaluationOptions(disallowStaleValue: true)
                )
            ]

            self.remoteDataAccess.status = .stale
            return try await featureFlagManager.flag(name: "foo")
        }

        #expect(flag.exists)
    }

    @Test
    func testNoFlags() async throws {
        self.remoteDataAccess.status = .upToDate
        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(name: "foo", isEligible: false, exists: false, variables: nil)
        #expect(expected == flag)
    }

    @Test
    func testFlagNoAudience() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
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
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        #expect(expected == flag)
    }

    @Test
    func testFlagAudienceMatch() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting",
            audienceSelector: DeviceAudienceSelector(newUser: true),
            compoundAudience: .init(selector: .not(.atomic(DeviceAudienceSelector(newUser: false)))),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(variables: nil)
            )
        )

        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, newUserDate, _ in
            #expect(selector == .combine(compoundSelector: flagInfo.compoundAudience?.selector, deviceSelector: flagInfo.audienceSelector)!)
            #expect(newUserDate == flagInfo.created)
            return .match
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == flag)
    }

    @Test
    func testFlagAudienceNoMatch() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting",
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
            return .miss
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == flag)
    }

    @Test
    func testAudienceMissLastInfoStatic() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting 1",
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
                reportingMetadata: "reporting 2",
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(.string("some variables"))
                    )
                )
            ),

        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting 2",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == flag)
    }

    @Test
    func testAudienceMissLastInfoDeferred() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting 1",
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
                reportingMetadata: "reporting 2",
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            ),

        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting 2",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == flag)
    }

    @Test
    func testMultipleFlags() async throws {
        let flagInfo1 = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting",
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
            reportingMetadata: "reporting",
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

        self.audienceChecker.onEvaluate = { selector,  _, _ in
            return if selector == .atomic(flagInfo2.audienceSelector!) {
                .match
            } else {
                .miss
            }
        }

        let flag = try await featureFlagManager.flag(name: "foo")

        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: AirshipJSON.string("flagInfo2 variables"),
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        #expect(expected == flag)
    }
    
    @Test
    func testMultipleFlagsCompound() async throws {
        let flagInfo1 = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting",
            audienceSelector: nil,
            compoundAudience: .init(selector: .atomic(DeviceAudienceSelector(newUser: true))),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(variables: nil)
            )
        )

        let flagInfo2 = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting",
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
            return if selector == flagInfo1.compoundAudience?.selector {
                .match
            } else {
                .miss
            }
        }

        let flag = try await featureFlagManager.flag(name: "foo")

        let expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        #expect(expected == flag)
    }

    @Test
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
            reportingMetadata: "reporting",
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
            return if selector == .atomic(variables[1].audienceSelector!) {
                .match
            } else {
                .miss
            }
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

        #expect(expected == flag)
    }
    
    @Test
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
            reportingMetadata: "reporting",
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant([])
                )
            ),
            controlOptions: .init(
                compoundAudience: .init(selector: .atomic(controlAudience)),
                reportingMetadata: "supersede",
                controlType: .flag)
        )
        
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]
        
        var audienceMatched = false

        self.audienceChecker.onEvaluate = { selector, _, _ in
            return if selector == .atomic(controlAudience), audienceMatched {
                .match
            } else {
                .miss
            }
        }

        
        let noControlFlag = try await featureFlagManager.flag(name: "foo")
        
        var expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        
        #expect(expected == noControlFlag)
        
        audienceMatched = true
        
        let controlFlag = try await featureFlagManager.flag(name: "foo")
        
        expected = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "supersede",
                supersededReportingMetadata: ["reporting"],
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == controlFlag)
    }
    
    @Test
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
            reportingMetadata: "reporting",
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant([])
                )
            ),
            controlOptions: .init(
                compoundAudience: .init(selector: .atomic(controlAudience)),
                reportingMetadata: "supersede",
                controlType: .variables("variables-overrides"))
        )
        
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            flagInfo,
        ]
        
        var audienceMatched = false
        self.audienceChecker.onEvaluate = { selector, _, _ in
            return if selector == .atomic(controlAudience), audienceMatched {
                .match
            } else {
                .miss
            }
        }
        
        let noControlFlag = try await featureFlagManager.flag(name: "foo")
        
        var expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        
        #expect(expected == noControlFlag)
        
        audienceMatched = true
        
        let controlFlag = try await featureFlagManager.flag(name: "foo")
        
        expected = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: "variables-overrides",
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "supersede",
                supersededReportingMetadata: ["reporting"],
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        #expect(expected == controlFlag)
    }
    
    @Test
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
            reportingMetadata: "reporting",
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: true, variables: .variant(variables), reportingMetadata: "reporting two")
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true,
            variables: variables[1].data,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "Variant reporting",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            return if selector == .atomic(variables[1].audienceSelector!) {
                .match
            } else {
                .miss
            }
        }

        await self.deferredResolver.setOnResolve { _, _ in
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        #expect(result == expectedFlag)
    }

    @Test
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
            reportingMetadata: "reporting",
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: false, variables: .variant(variables), reportingMetadata: "reporting two")
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting two",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            return if selector == .atomic(variables[1].audienceSelector!) {
                .match
            } else {
                .miss
            }
        }

        await self.deferredResolver.setOnResolve { _, _ in
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        #expect(result == expectedFlag)
    }


    @Test
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
            reportingMetadata: "reporting",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
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

        #expect(expected == flag)
    }

    @Test
    func testStaleNotDefined() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        #expect(
            flag ==
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: "reporting",
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    @Test
    func testStaleAllowed() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: false)
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        #expect(
            flag ==
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: "reporting",
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    @Test
    func testStaleNotAllowed() async throws {
        self.remoteDataAccess.status = .stale
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
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
            Issue.record("Should throw")
        } catch FeatureFlagError.staleData {
            // No-op
        } catch {
            Issue.record("Should throw staleData")
        }
    }

    @Test
    func testStaleNotAllowedMultipleFlags() async throws {
        self.remoteDataAccess.status = .stale

        // If one flag does not allow we ignore all
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
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
                reportingMetadata: "reporting",
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
            Issue.record("Should throw")
        }catch FeatureFlagError.staleData {
            // No-op
        } catch {
            Issue.record("Should throw staleData")
        }
    }

    @Test
    func testStaleAllowedOutOfDate() async throws {
        self.remoteDataAccess.status = .outOfDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                ),
                evaluationOptions: EvaluationOptions(disallowStaleValue: false)
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        #expect(
            flag ==
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: "reporting",
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    @Test
    func testOutOfDate() async throws {
        self.remoteDataAccess.status = .outOfDate

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting",
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
                reportingMetadata: "reporting",
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
            Issue.record("Should throw")
        } catch FeatureFlagError.outOfDate {
            // No-op
        } catch {
            Issue.record("Should throw outOfDate")
        }
    }

    @Test
    func testMultipleFlagsNotEligible() async throws {
        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting one",
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
                reportingMetadata: "reporting two",
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        #expect(
            flag ==
            FeatureFlag(
                name: "foo",
                isEligible: false,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: "reporting two",
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    @Test
    func testTrackInteractive() async throws {
        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting one",
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
                reportingMetadata: "reporting two",
                audienceSelector: DeviceAudienceSelector(newUser: true),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        #expect(
            flag ==
            FeatureFlag(
                name: "foo",
                isEligible: false,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: "reporting two",
                    contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )
    }

    @Test
    func testTrackInteraction() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting two",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.featureFlagManager.trackInteraction(flag: flag)
        #expect(self.analytics.trackedInteractions == [flag])
    }

    @Test
    func testDeferred() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
            audienceSelector: DeviceAudienceSelector(newUser: true),
            flagPayload: .deferredPayload(
                FeatureFlagPayload.DeferredInfo(
                    deferred: .init(url: URL(string: "some-url://")!)
                )
            )
        )

        let deferredResponse = DeferredFlagResponse.found(
            DeferredFlag(isEligible: false, variables: nil, reportingMetadata: "reporting two")
        )

        let expectedFlag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: "reporting two",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.remoteDataAccess.flagInfos = [
            flagInfo
        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.deferredResolver.setOnResolve { [deviceInfoProvider] request, info in
            #expect(request.url == URL(string: "some-url://"))
            #expect(request.contactID == deviceInfoProvider.stableContactInfo.contactID)
            #expect(request.channelID == deviceInfoProvider.channelID)
            #expect(request.locale == deviceInfoProvider.locale)
            #expect(request.notificationOptIn == deviceInfoProvider.isUserOptedInPushNotifications)
            #expect(flagInfo == info)
            return deferredResponse
        }

        let result = try await featureFlagManager.flag(name: "foo")
        #expect(result == expectedFlag)
    }

    @Test
    func testDeferredLocalAudience() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        await self.deferredResolver.setOnResolve { _, _ in
            Issue.record("Unexpected")
            throw AirshipErrors.error("Failed")
        }

        let result = try await featureFlagManager.flag(name: "foo")
        #expect(!result.isEligible)
    }

    @Test
    func testMultipleDeferred() async throws {
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "one",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: "reporting one",
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
                reportingMetadata: "reporting two",
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
                reportingMetadata: "reporting three",
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        deferred: .init(url: URL(string: "some-url://")!)
                    )
                )
            )
        ]

        self.audienceChecker.onEvaluate = { selector, _, _ in
            if selector == .atomic(DeviceAudienceSelector(newUser: true)) {
                return .match
            } else {
                return .miss
            }
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
                reportingMetadata: "reporting three",
                contactID: self.deviceInfoProvider.stableContactInfo.contactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        let result = try await featureFlagManager.flag(name: "foo")
        #expect(expectedFlag == result)

        let resolved = await self.deferredResolver.resolvedFlagInfos
        #expect(
            [
                self.remoteDataAccess.flagInfos[1],
                self.remoteDataAccess.flagInfos[2]
            ] == resolved
        )
    }


    @Test
    func testDeferredOutOfDate() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw FeatureFlagEvaluationError.outOfDate
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            #expect(error as! FeatureFlagError == FeatureFlagError.outOfDate)
        }

        #expect(remoteDataAccess.lastOutdatedRemoteInfo == self.remoteDataAccess.remoteDataInfo)
    }

    @Test
    func testDeferredConnectionIssue() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .miss
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw FeatureFlagEvaluationError.connectionError(errorMessage: "Failed to resolve flag.")
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            #expect(error as! FeatureFlagError == FeatureFlagError.connectionError(errorMessage: "Failed to resolve flag."))
        }

        #expect(remoteDataAccess.lastOutdatedRemoteInfo == nil)
    }

    @Test
    func testDeferredOtherError() async throws {
        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw AirshipErrors.error("other!")
        }

        do {
            _ = try await featureFlagManager.flag(name: "foo")
        } catch {
            #expect(error as! FeatureFlagError == FeatureFlagError.failedToFetchData)
        }

        #expect(remoteDataAccess.lastOutdatedRemoteInfo == nil)
    }

    @Test
    func testResultCacheFlagDoesNotExist() async throws {
        let cachedValue = FeatureFlag(
            name: "does-not-exist",
            isEligible: true,
            exists: false
        )


        await self.deferredResolver.setOnResolve { _, _ in
            throw AirshipErrors.error("other!")
        }

        await featureFlagManager.resultCache.cache(flag: cachedValue, ttl: .infinity)

        let flag = try await featureFlagManager.flag(name: "does-not-exist")
        let flagNoCache = try await featureFlagManager.flag(name: "does-not-exist", useResultCache: false)

        #expect(flag == cachedValue)
        #expect(flagNoCache != cachedValue)
    }

    @Test
    func testResultCacheThrows() async throws {
        let cachedValue = FeatureFlag(
            name: "foo",
            isEligible: true,
            exists: true
        )
        await featureFlagManager.resultCache.cache(flag: cachedValue, ttl: .infinity)

        let flagInfo = FeatureFlagInfo(
            id: "some ID",
            created: Date(),
            lastUpdated: Date(),
            name: "foo",
            reportingMetadata: "reporting one",
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

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.deferredResolver.setOnResolve { _, _ in
            throw AirshipErrors.error("other!")
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        do {
            _ = try await featureFlagManager.flag(name: "foo", useResultCache: false)
            Issue.record("Unexpected")
        } catch {}

        #expect(flag == cachedValue)
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
    
    var bestEffortRefresh: (() -> Void)?
    func bestEffortRefresh() async {
        self.bestEffortRefresh?()
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
