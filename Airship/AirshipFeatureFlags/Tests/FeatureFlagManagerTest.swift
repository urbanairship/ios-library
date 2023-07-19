/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class AirshipFeatureFlagsTest: XCTestCase {

    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let remoteDataAccess: TestFeatureFlagRemoteDataAccess = TestFeatureFlagRemoteDataAccess()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()

    private var featureFlagManager: FeatureFlagManager!

    override func setUp() {
        self.featureFlagManager = FeatureFlagManager(
            dataStore: self.dataStore,
            remoteDataAccess: self.remoteDataAccess,
            audienceChecker: self.audienceChecker,
            date: self.date
        )
    }

    func testFlagAccessRefreshesRemoteData() async throws {
        let _ = try await featureFlagManager.flag(name: "foo")
        XCTAssertTrue(self.remoteDataAccess.refreshed)
    }

    func testNoFlags() async throws {
        self.remoteDataAccess.status = .upToDate
        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: false, exists: false, variables: nil)
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
        let expected = FeatureFlag(isEligible: true, exists: true, variables: nil)
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

        self.audienceChecker.onEvaluate = { selector, newUserDate, contactID, _ in
            XCTAssertEqual(selector, flagInfo.audienceSelector)
            XCTAssertEqual(newUserDate, flagInfo.created)
            XCTAssertNil(contactID)
            return true
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: true, exists: true, variables: nil)
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

        self.audienceChecker.onEvaluate = { _, _, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: false, exists: true, variables: nil)
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

        self.audienceChecker.onEvaluate = { selector, _, _, _ in
            return selector == flagInfo2.audienceSelector
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: true, exists: true, variables: AirshipJSON.string("flagInfo2 variables"))
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

        self.audienceChecker.onEvaluate = { selector, _, _, _ in
            // match second variant
            return selector == variables[1].audienceSelector
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: true, exists: true, variables: variables[1].data)
        XCTAssertEqual(expected, flag)
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

        self.audienceChecker.onEvaluate = { selector, _, _, _ in
            return false
        }

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: true, exists: true, variables: nil)
        XCTAssertEqual(expected, flag)
    }

    func testDeferredIgnored() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                flagPayload: .deferredPayload(
                    FeatureFlagPayload.DeferredInfo(
                        url: URL(string:"some:url")!,
                        retryOnTimeout: true
                    )
                )
            )
        ]

        let flag = try await featureFlagManager.flag(name: "foo")
        let expected = FeatureFlag(isEligible: false, exists: false, variables: nil)
        XCTAssertEqual(expected, flag)
    }

    func testInactiveIgnored() async throws {
        self.remoteDataAccess.status = .upToDate
        self.remoteDataAccess.flagInfos = [
            FeatureFlagInfo(
                id: "some ID",
                created: Date(),
                lastUpdated: Date(),
                name: "foo",
                reportingMetadata: .string("reporting"),
                timeCriteria: AirshipTimeCriteria(
                    start: self.date.now + 1,
                    end: self.date.now + 2
                ),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: .fixed(nil)
                    )
                )
            )
        ]

        var flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(flag, FeatureFlag(isEligible: false, exists: false, variables: nil))

        self.date.offset += 1
        flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(flag, FeatureFlag(isEligible: true, exists: true, variables: nil))

        self.date.offset += 1
        flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(flag, FeatureFlag(isEligible: false, exists: false, variables: nil))
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
        XCTAssertEqual(flag, FeatureFlag(isEligible: true, exists: true, variables: nil))
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
        XCTAssertEqual(flag, FeatureFlag(isEligible: true, exists: true, variables: nil))
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
        } catch FeatureFlagError.failedToFetchData {
            // No-op
        } catch {
            XCTFail("Should throw failedToFetchData")
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
        } catch FeatureFlagError.failedToFetchData {
            // No-op
        } catch {
            XCTFail("Should throw failedToFetchData")
        }
    }

    func testOutOfDate() async throws {
        self.remoteDataAccess.status = .outOfDate

        do {
            let _ = try await featureFlagManager.flag(name: "foo")
            XCTFail("Should throw")
        } catch FeatureFlagError.failedToFetchData {
            // No-op
        } catch {
            XCTFail("Should throw failedToFetchData")
        }
    }
}

final class TestFeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol, @unchecked Sendable {
    var status: RemoteDataSourceStatus = .upToDate
    var flagInfos: [FeatureFlagInfo] = []

    var refreshed: Bool = false
    func refresh() async -> RemoteDataSourceStatus {
        self.refreshed = true
        return status
    }
}
