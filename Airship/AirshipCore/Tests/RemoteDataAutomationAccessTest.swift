/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataAutomationAccessTest: XCTestCase {
    
    private let remoteData: TestRemoteData = TestRemoteData()
    private let networkCheckeer: TestNetworkChecker = TestNetworkChecker()
    private var subject: _RemoteDataAutomationAccess!

    override func setUpWithError() throws {
        subject = _RemoteDataAutomationAccess(
            remoteData: remoteData,
            network: networkCheckeer
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
        await self.networkCheckeer.setConnected(true)
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
        await self.networkCheckeer.setConnected(true)
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
        await self.networkCheckeer.setConnected(true)
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
        await self.networkCheckeer.setConnected(false)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            XCTFail()
        }

        let result = await subject.bestEffortRefresh(remoteDataInfo: info)
        XCTAssertTrue(result)
    }

    func makeRemoteDataInfo(_ source: RemoteDataSource = .app) -> RemoteDataInfo {
        return RemoteDataInfo(url: URL(string: "https://airship.test")!,
                              lastModifiedTime: nil,
                              source: source)
    }
}
