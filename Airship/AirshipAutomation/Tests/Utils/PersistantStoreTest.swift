/* Copyright Airship and Contributors */

import XCTest

import AirshipCore
@testable
import AirshipAutomation

final class PersistantStoreTest: XCTestCase {
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var persistantStore: PersistantStore<TestData>!

    private let prefix = UUID().uuidString

    override func setUp() async throws {
        self.persistantStore = PersistantStore(dataStore: dataStore, prefix: prefix)
    }

    func testPrefix() {
        let data = TestData()
        self.persistantStore.setValue(data, forKey: "some-key")
        XCTAssertEqual(data, self.dataStore.safeCodable(forKey: "\(prefix)some-key"))
    }

    func testStore() {
        let data = TestData()
        self.persistantStore.setValue(data, forKey: "some-key")
        XCTAssertEqual(data, self.persistantStore.value(forKey: "some-key"))
    }

    func testNill() {
        XCTAssertNil(self.persistantStore.value(forKey: "some-key"))

        self.persistantStore.setValue(nil, forKey: "some-key")
        XCTAssertNil(self.persistantStore.value(forKey: "some-key"))
    }

    func testCodableError() {
        /// Set data in the store directly that will cause a codable error
        self.dataStore.setBool(true, forKey: "\(prefix)some-key")
        
        XCTAssertNil(self.persistantStore.value(forKey: "some-key"))
    }

    struct TestData: Codable, Equatable {
        let value: String

        init(value: String = UUID().uuidString) {
            self.value = value
        }
    }

}
