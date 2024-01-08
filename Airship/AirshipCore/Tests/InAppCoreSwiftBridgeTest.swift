/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class InAppCoreSwiftBridgeTest: XCTestCase {

    private let remoteData: TestRemoteData = TestRemoteData()
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let contact: TestContact = TestContact()
    private let meteredUsage: TestMeteredUsage = TestMeteredUsage()
    private let experiments: TestExperimentDataProvider = TestExperimentDataProvider()
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()

    private let defe: TestContact = TestContact()

    private var subject: _InAppCoreSwiftBridge!

    override func setUpWithError() throws {
        subject = _InAppCoreSwiftBridge(
            remoteData: remoteData,
            meteredUsage: meteredUsage,
            contact: contact,
            deferredResolver: deferredResolver,
            network: networkChecker,
            experimentProvider: experiments
        )
    }

    func testIsCurrentTrue() async {
        let info = makeRemoteDataInfo()

        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(remoteDataInfo: info)
        XCTAssertTrue(isCurrent)
    }

    func testIsCurrentFalse() async {
        let info = makeRemoteDataInfo()

        remoteData.isCurrent = false
        let isCurrent = await subject.isCurrent(remoteDataInfo: info)
        XCTAssertFalse(isCurrent)
    }

    func testIsCurrentNilRemoteDataInfo() async {
        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(remoteDataInfo: nil)
        XCTAssertFalse(isCurrent)
    }

    func testRequiresUpdateUpToDate() async {
        let info = makeRemoteDataInfo(.app)
        remoteData.isCurrent = true
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(remoteDataInfo: info)
        XCTAssertFalse(requiresUpdate)
    }

    func testRequiresUpdateStale() async {
        let info = makeRemoteDataInfo(.app)
        remoteData.isCurrent = true
        remoteData.status[.app] = .stale

        let requiresUpdate = await subject.requiresUpdate(remoteDataInfo: info)
        XCTAssertFalse(requiresUpdate)
    }

    func testRequiresUpdateOutOfDate() async {
        let info = makeRemoteDataInfo(.app)
        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate

        let requiresUpdate = await subject.requiresUpdate(remoteDataInfo: info)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateNotCurrent() async {
        let info = makeRemoteDataInfo(.app)
        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(remoteDataInfo: info)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateNilRemoteDataInfo() async {
        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(remoteDataInfo: nil)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateRightSource() async {
        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate
        remoteData.status[.contact] = .upToDate

        let requiresUpdateContact = await subject.requiresUpdate(
            remoteDataInfo: makeRemoteDataInfo(.contact)
        )
        XCTAssertFalse(requiresUpdateContact)

        let requiresUpdateApp = await subject.requiresUpdate(
            remoteDataInfo: makeRemoteDataInfo(.app)
        )
        XCTAssertTrue(requiresUpdateApp)

    }

    func testWaitForFullRefresh() async {
        let info = makeRemoteDataInfo(.contact)

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshBlock = { source, maxTime in
            XCTAssertEqual(source, .contact)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }

        await subject.waitFullRefresh(remoteDataInfo: info)
        await self.fulfillmentCompat(of: [expectation])
    }

    func testWaitForFullRefreshNilInfo() async {
        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshBlock = { source, maxTime in
            XCTAssertEqual(source, .app)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }

        await subject.waitFullRefresh(remoteDataInfo: nil)
        await self.fulfillmentCompat(of: [expectation])
    }

    func testBestEffortRefresh() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
            XCTAssertEqual(source, .contact)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }

        let result = await subject.bestEffortRefresh(remoteDataInfo: info)
        await self.fulfillmentCompat(of: [expectation])
        XCTAssertTrue(result)
    }

    func testBestEffortRefreshNotCurrentAfterAttempt() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
            self.remoteData.isCurrent = false
            expectation.fulfill()
        }

        let result = await subject.bestEffortRefresh(remoteDataInfo: info)
        await self.fulfillmentCompat(of: [expectation])
        XCTAssertFalse(result)
    }

    func testBestEffortRefreshNotCurrentReturnsNil() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = false
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            XCTFail()
        }

        let result = await subject.bestEffortRefresh(remoteDataInfo: info)
        XCTAssertFalse(result)
    }

    func testBestEffortRefreshNotConnected() async {
        await self.networkChecker.setConnected(false)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            XCTFail()
        }

        let result = await subject.bestEffortRefresh(remoteDataInfo: info)
        XCTAssertTrue(result)
    }

    func testAddImpression() async throws {
        contact.contactID = "some other contact"
        await subject.addImpression(
            entityID: "some entity ID",
            product: "some product",
            contactID: "some contact",
            reportingContext: ["reporting": "context"]
        )
        XCTAssertEqual(1, self.meteredUsage.events.count)
        let event = self.meteredUsage.events.first!

        XCTAssertEqual(event.entityID, "some entity ID")
        XCTAssertEqual(event.product, "some product")
        XCTAssertEqual(event.contactId, "some contact")
        XCTAssertEqual(event.usageType, .inAppExperienceImpression)

        XCTAssertEqual(event.reportingContext, try AirshipJSON.wrap(["reporting": "context"]))
    }


    func testAddImpressionFallbackContactID() async throws {
        contact.contactID = "some other contact"
        await subject.addImpression(
            entityID: "some entity ID",
            product: "some product",
            contactID: nil,
            reportingContext: ["reporting": "context"]
        )

        XCTAssertEqual(1, self.meteredUsage.events.count)
        let event = self.meteredUsage.events.first!

        XCTAssertEqual(event.entityID, "some entity ID")
        XCTAssertEqual(event.product, "some product")
        XCTAssertEqual(event.contactId, "some other contact")
        XCTAssertEqual(event.reportingContext, try AirshipJSON.wrap(["reporting": "context"]))
    }

    func testResolveDeferred() async throws {
        let deviceInfo = TestAudienceDeviceInfoProvider()
        deviceInfo.locale = Locale(identifier: "de-DE")
        let now = Date()

        let responseBody = AirshipJSON.string("result!")
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: now,
            deviceInfo: deviceInfo,
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { request in
            let expected = DeferredRequest(
                url: URL(string: "https://example.com")!,
                channelID: "some channel ID",
                contactID: deviceInfo.stableContactID,
                triggerContext: AirshipTriggerContext(
                    type: "some trigger type",
                    goal: 10.0,
                    event: try! AirshipJSON.wrap(["some": "event"])
                ),
                locale: deviceInfo.locale,
                notificationOptIn: deviceInfo.isUserOptedInPushNotifications
            )
            XCTAssertEqual(expected, request)
            return .success(try! responseBody.toData())
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(responseBody, try! AirshipJSON.wrap(result.responseBody))
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testResolveDeferredTimedOut() async throws {
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: Date(),
            deviceInfo: TestAudienceDeviceInfoProvider(),
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { _ in
            return .timedOut
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertTrue(result.timedOut)
            XCTAssertNil(result.responseBody)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testResolveDeferredOutOfDate() async throws {
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: Date(),
            deviceInfo: TestAudienceDeviceInfoProvider(),
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { _ in
            return .outOfDate
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertTrue(result.isOutOfDate)
            XCTAssertNil(result.responseBody)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testResolveDeferredNotFound() async throws {
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: Date(),
            deviceInfo: TestAudienceDeviceInfoProvider(),
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { _ in
            return .notFound
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertTrue(result.isOutOfDate)
            XCTAssertNil(result.responseBody)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testResolveDeferredErrorNoBackoff() async throws {
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: Date(),
            deviceInfo: TestAudienceDeviceInfoProvider(),
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { _ in
            return .retriableError()
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertFalse(result.isOutOfDate)
            XCTAssertEqual(-1, result.backOff)
            XCTAssertNil(result.responseBody)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func testResolveDeferredErrorBackoff() async throws {
        let audience = _InAppAudience(
            audienceSelector: nil,
            newUserEvaluationDate: Date(),
            deviceInfo: TestAudienceDeviceInfoProvider(),
            experimentProvider: self.experiments
        )

        self.deferredResolver.onData = { _ in
            return .retriableError(retryAfter: 10.0)
        }

        let expectation = expectation(description: "resolved")
        subject.resolveDeferred(
            url: URL(string: "https://example.com")!,
            channelID: "some channel ID",
            audience: audience,
            triggerType: "some trigger type",
            triggerEvent: ["some": "event"],
            triggerGoal: 10.0
        ) { result in
            XCTAssertFalse(result.isSuccess)
            XCTAssertFalse(result.isOutOfDate)
            XCTAssertEqual(10.0, result.backOff)
            XCTAssertNil(result.responseBody)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation])
    }

    func makeRemoteDataInfo(_ source: RemoteDataSource = .app) -> RemoteDataInfo {
        return RemoteDataInfo(url: URL(string: "https://airship.test")!,
                              lastModifiedTime: nil,
                              source: source)
    }
}

fileprivate final class TestMeteredUsage: AirshipMeteredUsageProtocol, @unchecked Sendable {
    var events: [AirshipMeteredUsageEvent] = []
    func addEvent(_ event: AirshipMeteredUsageEvent) async throws {
        events.append(event)
    }
}

