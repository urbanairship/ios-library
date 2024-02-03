/* Copyright Airship and Contributors */

import XCTest

import AirshipCore
@testable
import AirshipAutomation

final class AutomationRemoteDataAccessTest: XCTestCase {
    private let remoteData: TestRemoteData = TestRemoteData()
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private var subject: AutomationRemoteDataAccess!

    override func setUpWithError() throws {
        subject = AutomationRemoteDataAccess(
            remoteData: remoteData,
            network: networkChecker
        )
    }

    func testIsCurrentTrue() async {
        let info = makeRemoteDataInfo()
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(schedule: schedule)
        XCTAssertTrue(isCurrent)
    }

    func testIsCurrentFalse() async {
        let info = makeRemoteDataInfo()
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = false
        let isCurrent = await subject.isCurrent(schedule: schedule)
        XCTAssertFalse(isCurrent)
    }

    func testIsCurrentNilRemoteDataInfo() async {
        let schedule = makeSchedule(remoteDataInfo: nil)

        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(schedule: schedule)
        XCTAssertFalse(isCurrent)
    }

    func testRequiresUpdateUpToDate() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        XCTAssertFalse(requiresUpdate)
    }

    func testRequiresUpdateStale() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .stale

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        XCTAssertFalse(requiresUpdate)
    }

    func testRequiresUpdateOutOfDate() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateNotCurrent() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateNilRemoteDataInfo() async {
        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let schedule = makeSchedule(remoteDataInfo: nil)

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        XCTAssertTrue(requiresUpdate)
    }

    func testRequiresUpdateRightSource() async {
        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate
        remoteData.status[.contact] = .upToDate

        let requiresUpdateContact = await subject.requiresUpdate(
            schedule: makeSchedule(remoteDataInfo: makeRemoteDataInfo(.contact))
        )
        XCTAssertFalse(requiresUpdateContact)

        let requiresUpdateApp = await subject.requiresUpdate(
            schedule: makeSchedule(remoteDataInfo: makeRemoteDataInfo(.app))
        )
        XCTAssertTrue(requiresUpdateApp)
    }

    func testWaitForFullRefresh() async {
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshBlock = { source, maxTime in
            XCTAssertEqual(source, .contact)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }
        

        await subject.waitFullRefresh(schedule: schedule)
        await self.fulfillmentCompat(of: [expectation])
    }

    func testWaitForFullRefreshNilInfo() async {
        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshBlock = { source, maxTime in
            XCTAssertEqual(source, .app)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }

        let schedule = makeSchedule(remoteDataInfo: nil)
        await subject.waitFullRefresh(schedule: schedule)
        await self.fulfillmentCompat(of: [expectation])
    }

    func testBestEffortRefresh() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let schedule = makeSchedule(remoteDataInfo: info)

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
            XCTAssertEqual(source, .contact)
            XCTAssertNil(maxTime)
            expectation.fulfill()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        await self.fulfillmentCompat(of: [expectation])
        XCTAssertTrue(result)
    }

    func testBestEffortRefreshNotCurrentAfterAttempt() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let schedule = makeSchedule(remoteDataInfo: info)

        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
            self.remoteData.isCurrent = false
            expectation.fulfill()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        await self.fulfillmentCompat(of: [expectation])
        XCTAssertFalse(result)
    }

    func testBestEffortRefreshNotCurrentReturnsNil() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = false
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            XCTFail()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        XCTAssertFalse(result)
    }

    func testBestEffortRefreshNotConnected() async {
        await self.networkChecker.setConnected(false)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            XCTFail()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        XCTAssertTrue(result)
    }

    func testNotifyOutdated() async {
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        await self.subject.notifyOutdated(schedule: schedule)
        XCTAssertEqual(self.remoteData.notifiedOutdatedInfos, [info])
    }
    
    private func makeSchedule(remoteDataInfo: RemoteDataInfo?) -> AutomationSchedule {
        return AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(AirshipJSON.null),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            metadata: try! AirshipJSON.wrap([
                "com.urbanairship.iaa.REMOTE_DATA_INFO": remoteDataInfo
            ])
        )
    }
    private func makeRemoteDataInfo(_ source: RemoteDataSource = .app) -> RemoteDataInfo {
        return RemoteDataInfo(
            url: URL(string: "https://airship.test")!,
            lastModifiedTime: nil,
            source: source
        )
    }

}
