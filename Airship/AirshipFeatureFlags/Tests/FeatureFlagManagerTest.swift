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
    private let eventTracker: TestEventTracker = TestEventTracker()
    private let deviceInfoProvider: TestDeviceInfoProvider = TestDeviceInfoProvider()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())

    private var featureFlagManager: FeatureFlagManager!

    override func setUp() {
        self.featureFlagManager = FeatureFlagManager(
            dataStore: self.dataStore,
            remoteDataAccess: self.remoteDataAccess,
            eventTracker: self.eventTracker,
            audienceChecker: self.audienceChecker,
            date: self.date,
            deviceInfoProviderFactory: { self.deviceInfoProvider },
            notificationCenter: notificationCenter
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
                contactID: self.deviceInfoProvider.stableContactID,
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
                contactID: self.deviceInfoProvider.stableContactID,
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
                contactID: self.deviceInfoProvider.stableContactID,
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
                contactID: self.deviceInfoProvider.stableContactID,
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
                contactID: self.deviceInfoProvider.stableContactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

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
                contactID: self.deviceInfoProvider.stableContactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

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
        let expected = FeatureFlag(name: "foo", isEligible: false, exists: false, variables: nil)
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
        XCTAssertEqual(flag, FeatureFlag(name: "foo", isEligible: false, exists: false, variables: nil))

        self.date.offset += 1
        flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag,
            FeatureFlag(
                name: "foo",
                isEligible: true,
                exists: true,
                variables: nil,
                reportingInfo: FeatureFlag.ReportingInfo(
                    reportingMetadata: .string("reporting"),
                    contactID: self.deviceInfoProvider.stableContactID,
                    channelID: self.deviceInfoProvider.channelID
                )
            )
        )

        self.date.offset += 1
        flag = try await featureFlagManager.flag(name: "foo")
        XCTAssertEqual(
            flag, 
            FeatureFlag(name: "foo", isEligible: false, exists: false, variables: nil)
        )
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
                    contactID: self.deviceInfoProvider.stableContactID,
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
                    contactID: self.deviceInfoProvider.stableContactID,
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
                    contactID: self.deviceInfoProvider.stableContactID,
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
                    contactID: self.deviceInfoProvider.stableContactID,
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
                contactID: self.deviceInfoProvider.stableContactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )
        
        let expectation = self.expectation(description: "tracked notification sent")
        notificationCenter.addObserver(forName: AirshipAnalytics.featureFlagInterracted) { notification in
            let event = self.eventTracker.events.last as? FeatureFlagInteractedEvent
            let receivedEvent = notification.userInfo?[AirshipAnalytics.eventKey] as? FeatureFlagInteractedEvent
            XCTAssertNotNil(event)
            XCTAssertEqual(event, receivedEvent)
            expectation.fulfill()
        }

        self.featureFlagManager.trackInteraction(flag: flag)

        XCTAssertEqual(1, self.eventTracker.events.count)
        XCTAssertNotNil(self.eventTracker.events[0] as? FeatureFlagInteractedEvent)
        
        waitForExpectations(timeout: 10)
    }

    func testTrackInteractionDoesNotExist() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: false,
            variables: nil,
            reportingInfo: FeatureFlag.ReportingInfo(
                reportingMetadata: .string("reporting two"),
                contactID: self.deviceInfoProvider.stableContactID,
                channelID: self.deviceInfoProvider.channelID
            )
        )

        self.featureFlagManager.trackInteraction(flag: flag)

        XCTAssertEqual(0, self.eventTracker.events.count)
    }

    func testTrackInteractionNoReportingInfo() {
        let flag = FeatureFlag(
            name: "foo",
            isEligible: false,
            exists: true,
            variables: nil,
            reportingInfo: nil
        )

        self.featureFlagManager.trackInteraction(flag: flag)
        XCTAssertEqual(0, self.eventTracker.events.count)
    }

}

final class TestFeatureFlagRemoteDataAccess: FeatureFlagRemoteDataAccessProtocol, @unchecked Sendable {
    var waitForRefreshBlock: (() -> Void)?
    func waitForRefresh() async {
        self.waitForRefreshBlock?()
    }
    
    var status: RemoteDataSourceStatus = .upToDate
    var flagInfos: [FeatureFlagInfo] = []
}


final class TestEventTracker: EventTracker, @unchecked Sendable {
    var events: [AirshipEvent] = []
    func addEvent(_ event: AirshipEvent) {
        events.append(event)
    }
}


final class TestDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    var sdkVersion: String = "1.0.0"


    var isAirshipReady: Bool = false

    var tags: Set<String> = Set()

    var channelID: String? = UUID().uuidString

    var locale: Locale = Locale.current

    var appVersion: String?
    
    var permissions: [AirshipCore.AirshipPermission : AirshipCore.AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactID: String = UUID().uuidString

}
