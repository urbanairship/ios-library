/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataAutomationAccessTest: XCTestCase {
    
    private var subject: _RemoteDataAutomationAccess!
    private var remoteData: TestRemoteData!
    private let networkMonitor = TestNetworkMonitor()

    override func setUpWithError() throws {
        remoteData = TestRemoteData()
        subject = _RemoteDataAutomationAccess(remoteData: remoteData, networkMonitor: networkMonitor)
        networkMonitor.isConnectedOverride = true
    }

    func testRemoteDataCalledOnceIfStale() async {
        var updates = [RemoteDataSource: UInt]()
        remoteData.refreshBlock = { source in
            let current = updates[source] ?? 0
            updates[source] = current + 1
            self.remoteData.status[source] = .upToDate
            return true
        }

        remoteData.status[.app] = .stale
        
        let responses = [
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo())
        ]
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 1)
        let appSource = updates[.app]
        XCTAssertNotNil(appSource)
        XCTAssert(appSource == 1)
    }
    
    func testRemoteDataCalledIfStaleInParallel() async {
        var updates = [RemoteDataSource: UInt]()
        remoteData.refreshBlock = { source in
            let current = updates[source] ?? 0
            updates[source] = current + 1
            self.remoteData.status[source] = .upToDate
            return true
        }

        remoteData.status[.app] = .stale


        async let operations = [
            self.subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            self.subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            self.subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            self.subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo())
        ]
        
        let responses = await operations
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 1)
        let appSource = updates[.app]
        XCTAssertNotNil(appSource)
        XCTAssert(appSource == 1)
    }
    
    func testStaleAfterUpdate() async {
        var updates = [RemoteDataSource: UInt]()
        remoteData.refreshBlock = { source in
            let current = updates[source] ?? 0
            updates[source] = current + 1
            self.remoteData.status[source] = .upToDate
            return true
        }

        remoteData.status[.app] = .stale

        var responses = [
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
        ]
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 1)
        XCTAssert(updates[.app] == 1)
        
        remoteData.status[.app] = .stale
        
        responses = [
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
        ]
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 1)
        XCTAssert(updates[.app] == 2)
    }
    
    func testDifferentStoreHasDifferentCache() async {
        
        var updates = [RemoteDataSource: UInt]()
        remoteData.refreshBlock = { source in
            let current = updates[source] ?? 0
            updates[source] = current + 1
            self.remoteData.status[source] = .upToDate
            return true
        }
        
        var responses = [
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo(.contact)),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo(.contact))
        ]
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 2)
        XCTAssert(updates[.app] == 1)
        XCTAssert(updates[.contact] == 1)
        
        remoteData.status[.app] = .stale
        remoteData.status[.contact] = .stale

        responses = [
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
            await subject.refreshAndCheckCurrent(remoteDataInfo: makeRemoteDataInfo()),
        ]
        
        XCTAssert(responses.allSatisfy({ $0 }))
        XCTAssert(updates.count == 2)
        XCTAssert(updates[.app] == 2)
        XCTAssert(updates[.contact] == 1)
    }
    
    func makeRemoteDataInfo(_ source: RemoteDataSource = .app) -> RemoteDataInfo {
        return RemoteDataInfo(url: URL(string: "https://airship.test")!,
                              lastModifiedTime: nil,
                              source: source)
    }
}
