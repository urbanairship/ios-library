/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataStoreTest: XCTestCase {
    
    private var remoteDataStore: RemoteDataStore?
    
    override func setUpWithError() throws {
        self.remoteDataStore = RemoteDataStore(
            storeName: self.name,
            inMemory: true
        )
    }

    
    func testFirstRemoteData() async throws {
        
        let testPayload = createRemoteDataPayload()
        
        try await self.remoteDataStore?.overwriteCachedRemoteData([testPayload])
        
        let remoteDataStorePayloads = try await self.remoteDataStore?.fetchRemoteDataFromCache(predicate: nil)

        XCTAssertEqual(1, remoteDataStorePayloads!.count)
        let dataStorePayload = remoteDataStorePayloads![0]
        XCTAssertEqual(testPayload.type, dataStorePayload.type)
        XCTAssertEqual(testPayload.timestamp, dataStorePayload.timestamp)
        XCTAssertEqual(testPayload.data as! [String : [String : String]], dataStorePayload.data as! [String : [String : String]])
        XCTAssertEqual(testPayload.metadata as! [String : String], dataStorePayload.metadata as! [String : String])
            
    }
    
    func testNewRemoteData() async throws {
        let testPayloads = [
            createRemoteDataPayload(),
            createRemoteDataPayload(),
            createRemoteDataPayload()
        ]
        
        try await self.remoteDataStore?.overwriteCachedRemoteData(testPayloads)
        
        var remoteDataStorePayloads = try await self.remoteDataStore?.fetchRemoteDataFromCache(predicate: nil)

        XCTAssertEqual(testPayloads.count, remoteDataStorePayloads!.count)
        for testPayload in testPayloads {
            var matchedPayloadTypes = false
            for dataStorePayload in remoteDataStorePayloads! {
                if testPayload.type == dataStorePayload.type {
                    XCTAssertEqual(testPayload.timestamp, dataStorePayload.timestamp)
                    XCTAssertEqual(testPayload.data as! [String : [String : String]], dataStorePayload.data as! [String : [String : String]])
                    XCTAssertEqual(testPayload.metadata as! [String : String], dataStorePayload.metadata as! [String : String])
                    matchedPayloadTypes = true
                }
            }
            XCTAssertTrue(matchedPayloadTypes)
        }
        
        let testPayload = createRemoteDataPayload(withType: testPayloads[1].type)
        
        // Sync only the modified message
        try await self.remoteDataStore?.overwriteCachedRemoteData([testPayload])
        
        // Verify we only have the modified message with the updated title
        remoteDataStorePayloads = try await self.remoteDataStore?.fetchRemoteDataFromCache(predicate: nil)
        
        XCTAssertEqual(1, remoteDataStorePayloads!.count)
        let dataStorePayload = remoteDataStorePayloads![0]
        XCTAssertEqual(testPayload.type, dataStorePayload.type)
        XCTAssertEqual(testPayload.timestamp, dataStorePayload.timestamp)
        XCTAssertEqual(testPayload.data as! [String : [String : String]], dataStorePayload.data as! [String : [String : String]])
        XCTAssertEqual(testPayload.metadata as! [String : String], dataStorePayload.metadata as! [String : String])
            
        
    }
    
    func createRemoteDataPayload(withType type: String? = nil) -> RemoteDataPayload {
        let payloadType = type ?? ProcessInfo.processInfo.globallyUniqueString
        let testPayload = RemoteDataPayload(
            type: payloadType,
            timestamp: Date(),
            data: [
                "message_center": [
                    "background_color": ProcessInfo.processInfo.globallyUniqueString,
                    "font": ProcessInfo.processInfo.globallyUniqueString
                ]
            ],
            metadata: [
                "cool": "story"
            ])
        return testPayload
    }
    
}
