/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataStoreTest: XCTestCase {

    private let remoteDataStore: RemoteDataStore = RemoteDataStore(
        storeName: "RemoteDataStoreTest",
        inMemory: true
    )

    func testFirstRemoteData() async throws {
        let testPayload = createRemoteDataPayload()

        try await self.remoteDataStore.overwriteCachedRemoteData([testPayload])

        let remoteDataStorePayloads = try await self.remoteDataStore.fetchRemoteDataFromCache()

        XCTAssertEqual([testPayload], remoteDataStorePayloads)
    }

    func testNewRemoteData() async throws {
        let testPayloads = [
            createRemoteDataPayload(),
            createRemoteDataPayload(),
            createRemoteDataPayload()
        ].sorted(by: { first, second in
            first.type > second.type
        })

        try await self.remoteDataStore.overwriteCachedRemoteData(testPayloads)

        var remoteDataStorePayloads = try await self.remoteDataStore.fetchRemoteDataFromCache()
            .sorted(by: { first, second in
                first.type > second.type
            })

        XCTAssertEqual(testPayloads, remoteDataStorePayloads)

        let testPayload = createRemoteDataPayload(withType: testPayloads[1].type)

        // Sync only the modified message
        try await self.remoteDataStore.overwriteCachedRemoteData([testPayload])

        // Verify we only have the modified message with the updated title
        remoteDataStorePayloads = try await self.remoteDataStore.fetchRemoteDataFromCache()

        XCTAssertEqual([testPayload], remoteDataStorePayloads)
    }


    func createRemoteDataPayload(withType type: String? = nil) -> RemoteDataPayload {
        return RemoteDataTestUtils.generatePayload(
            type: type ?? UUID().uuidString,
            timestamp: Date(),
            data: ["random": UUID().uuidString],
            source: .app
        )
    }

}
