/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class PreferenceDataStoreTest: XCTestCase {

    private let airshipDefaults = UserDefaults(
        suiteName: "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
    )!
    private let appKey = UUID().uuidString
    private let testDeviceID = TestDeviceID()
    
    func testPrefix() throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            dispatcher: TestDispatcher(),
            deviceID: testDeviceID
        )
        dataStore.setObject("neat", forKey: "some-key")
        XCTAssertEqual(
            "neat",
            airshipDefaults.string(forKey: "\(self.appKey)some-key")
        )
    }

    /// Tests merging data from the old keys in either standard or the Airship defaults:
    ///  - If a value exists under the old key but not the new key, it will be restored under the new key
    ///  - If channel tags exists under both keys we will merge the two tag arrays
    func testMergeKeys() throws {
        let standardDefaults = UserDefaults.standard
        let legacyPrefix = "com.urbanairship.\(appKey)."
        let newPrefix = self.appKey
        let tagsKey = "com.urbanairship.channel.tags"

        standardDefaults.set("keep-new: old", forKey: "\(legacyPrefix)keep-new")
        self.airshipDefaults.set(
            "keep-new: new",
            forKey: "\(newPrefix)keep-new"
        )
        standardDefaults.set(
            "restore-old: old",
            forKey: "\(legacyPrefix)restore-old"
        )

        self.airshipDefaults.set(
            "another-keep-new: old",
            forKey: "\(legacyPrefix)another-keep-new"
        )
        self.airshipDefaults.set(
            "another-keep-new: new",
            forKey: "\(newPrefix)another-keep-new"
        )
        self.airshipDefaults.set(
            "another-restore-old: old",
            forKey: "\(legacyPrefix)another-restore-old"
        )

        standardDefaults.set(["a", "b"], forKey: "\(legacyPrefix)\(tagsKey)")
        self.airshipDefaults.set(["c"], forKey: "\(newPrefix)\(tagsKey)")

        let dataStore = PreferenceDataStore(appKey: self.appKey)

        XCTAssertEqual(
            "another-keep-new: new",
            dataStore.string(forKey: "another-keep-new")
        )
        XCTAssertEqual(
            "another-restore-old: old",
            dataStore.string(forKey: "another-restore-old")
        )
        XCTAssertEqual("keep-new: new", dataStore.string(forKey: "keep-new"))
        XCTAssertEqual(
            "restore-old: old",
            dataStore.string(forKey: "restore-old")
        )
        XCTAssertEqual(["a", "b", "c"], dataStore.stringArray(forKey: tagsKey))
    }

    func testData() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)

        let data = "neat".data(using: .utf8)
        dataStore.setObject(data, forKey: "data")
        XCTAssertEqual(data, dataStore.data(forKey: "data"))

        dataStore.setBool(false, forKey: "falseBool")
        XCTAssertFalse(dataStore.bool(forKey: "falseBool"))

        dataStore.setBool(true, forKey: "trueBool")
        XCTAssertTrue(dataStore.bool(forKey: "trueBool"))

        let array = ["neat", "rad"]
        dataStore.setObject(array, forKey: "array")
        XCTAssertEqual(array, dataStore.array(forKey: "array"))

        let dict = ["neat": "rad"]
        dataStore.setObject(dict, forKey: "dict")
        XCTAssertEqual(
            dict,
            dataStore.dictionary(forKey: "dict") as! [String: String]
        )

        let float: Float = 2.0
        dataStore.setFloat(float, forKey: "float")
        XCTAssertEqual(float, dataStore.float(forKey: "float"))

        let double: Double = 3.0
        dataStore.setDouble(double, forKey: "double")
        XCTAssertEqual(double, dataStore.double(forKey: "double"))

        let int: Int = 1
        dataStore.setInteger(int, forKey: "int")
        XCTAssertEqual(int, dataStore.integer(forKey: "int"))

        let date = Date()
        dataStore.setObject(date, forKey: "date")
        XCTAssertEqual(date, dataStore.object(forKey: "date") as! Date)
    }

    func testNil() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)

        XCTAssertNil(dataStore.object(forKey: "nil?"))
        dataStore.setObject("not nil", forKey: "nil?")
        XCTAssertNotNil(dataStore.object(forKey: "nil?"))
        dataStore.setObject(nil, forKey: "nil?")
        XCTAssertNil(dataStore.object(forKey: "nil?"))
    }

    func testDefaults() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        XCTAssertEqual(
            100.0,
            dataStore.double(forKey: "neat", defaultValue: 100.0)
        )
        XCTAssertEqual(true, dataStore.bool(forKey: "neat", defaultValue: true))

        XCTAssertEqual(
            dataStore.double(forKey: "neat"),
            self.airshipDefaults.double(forKey: "neat")
        )

        XCTAssertEqual(
            dataStore.float(forKey: "neat"),
            self.airshipDefaults.float(forKey: "neat")
        )

        XCTAssertEqual(
            dataStore.bool(forKey: "neat"),
            self.airshipDefaults.bool(forKey: "neat")
        )

        XCTAssertEqual(
            dataStore.integer(forKey: "neat"),
            self.airshipDefaults.integer(forKey: "neat")
        )
    }

    func testCodable() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        let nilValue: FooCodable? = try dataStore.codable(forKey: "codable")
        XCTAssertNil(nilValue)
        let codable = FooCodable(foo: "woot")
        try dataStore.setCodable(codable, forKey: "codable")
        XCTAssertEqual(codable, try dataStore.codable(forKey: "codable"))
    }

    func testCodableWrongType() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        let foo = FooCodable(foo: "woot")

        try dataStore.setCodable(foo, forKey: "codable")
        XCTAssertThrowsError(
            try {
                let _: BarCodable? = try dataStore.codable(forKey: "codable")
            }()
        )
    }
    
    func testAppNotRestoredNoData() async throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            dispatcher: TestDispatcher(),
            deviceID: testDeviceID
        )

        let value = await dataStore.isAppRestore
        XCTAssertFalse(value)
    }
    
    func testAppRestoredDeviceIDChange() async throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            dispatcher: TestDispatcher(),
            deviceID: testDeviceID
        )
        var value = await dataStore.isAppRestore
        XCTAssertFalse(value)


        await self.testDeviceID.setValue(value: UUID().uuidString)
        value = await dataStore.isAppRestore
        XCTAssertTrue(value)
    }
}

private struct FooCodable: Codable, Equatable {
    let foo: String
}

private struct BarCodable: Codable, Equatable {
    let bar: String
}


fileprivate actor TestDeviceID: AirshipDeviceIDProtocol {
    var value: String = UUID().uuidString

    init() {}

    public func setValue(value: String) {
        self.value = value
    }
}
