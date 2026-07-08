/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct PreferenceDataStoreTest {

    private let airshipDefaults = UserDefaults(
        suiteName: "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
    )!
    private let appKey = UUID().uuidString
    private let testDeviceID = TestDeviceID()

    @Test
    func testPrefix() throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        dataStore.setObject("neat", forKey: "some-key")
        dataStore.waitForWrites()
        #expect(
            "neat" ==
            airshipDefaults.string(forKey: "\(self.appKey)some-key")
        )
    }

    /// Tests merging data from the old keys in either standard or the Airship defaults:
    ///  - If a value exists under the old key but not the new key, it will be restored under the new key
    ///  - If channel tags exists under both keys we will merge the two tag arrays
    @Test
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

        #expect(
            "another-keep-new: new" ==
            dataStore.string(forKey: "another-keep-new")
        )
        #expect(
            "another-restore-old: old" ==
            dataStore.string(forKey: "another-restore-old")
        )
        #expect("keep-new: new" == dataStore.string(forKey: "keep-new"))
        #expect(
            "restore-old: old" ==
            dataStore.string(forKey: "restore-old")
        )
        #expect(dataStore.stringArray(forKey: tagsKey) as? [String] == ["a", "b", "c"])
    }

    @Test
    func testData() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)

        let data = "neat".data(using: .utf8)
        dataStore.setObject(data, forKey: "data")
        #expect(data == dataStore.data(forKey: "data"))

        dataStore.setBool(false, forKey: "falseBool")
        #expect(!(dataStore.bool(forKey: "falseBool")))

        dataStore.setBool(true, forKey: "trueBool")
        #expect(dataStore.bool(forKey: "trueBool"))

        let array = ["neat", "rad"]
        dataStore.setObject(array, forKey: "array")
        #expect(array == dataStore.array(forKey: "array") as! [String])

        let dict = ["neat": "rad"]
        dataStore.setObject(dict, forKey: "dict")
        #expect(
            dict ==
            (dataStore.dictionary(forKey: "dict") as! [String: String])
        )

        let float: Float = 2.0
        dataStore.setFloat(float, forKey: "float")
        #expect(float == dataStore.float(forKey: "float"))

        let double: Double = 3.0
        dataStore.setDouble(double, forKey: "double")
        #expect(double == dataStore.double(forKey: "double"))

        let int: Int = 1
        dataStore.setInteger(int, forKey: "int")
        #expect(int == dataStore.integer(forKey: "int"))

        let date = Date()
        dataStore.setObject(date, forKey: "date")
        #expect(date == (dataStore.object(forKey: "date") as! Date))
    }

    @Test
    func testNil() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)

        #expect(dataStore.object(forKey: "nil?") == nil)
        dataStore.setObject("not nil", forKey: "nil?")
        #expect(dataStore.object(forKey: "nil?") != nil)
        dataStore.setObject(nil, forKey: "nil?")
        #expect(dataStore.object(forKey: "nil?") == nil)
    }

    @Test
    func testDefaults() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        #expect(
            100.0 ==
            dataStore.double(forKey: "neat", defaultValue: 100.0)
        )
        #expect(true == dataStore.bool(forKey: "neat", defaultValue: true))

        #expect(
            dataStore.double(forKey: "neat") ==
            self.airshipDefaults.double(forKey: "neat")
        )

        #expect(
            dataStore.float(forKey: "neat") ==
            self.airshipDefaults.float(forKey: "neat")
        )

        #expect(
            dataStore.bool(forKey: "neat") ==
            self.airshipDefaults.bool(forKey: "neat")
        )

        #expect(
            dataStore.integer(forKey: "neat") ==
            self.airshipDefaults.integer(forKey: "neat")
        )
    }

    @Test
    func testCodable() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        let nilValue: FooCodable? = try dataStore.codable(forKey: "codable")
        #expect(nilValue == nil)
        let codable = FooCodable(foo: "woot")
        try dataStore.setCodable(codable, forKey: "codable")
        #expect(codable == (try dataStore.codable(forKey: "codable")))
    }

    @Test
    func testCodableWrongType() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        let foo = FooCodable(foo: "woot")

        try dataStore.setCodable(foo, forKey: "codable")
        #expect(throws: (any Error).self) {
            let _: BarCodable? = try dataStore.codable(forKey: "codable")
        }
    }

    @Test
    func testAppNotRestoredNoData() async throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )

        let value = await dataStore.isAppRestore
        #expect(!(value))
    }

    @Test
    func testAppRestoredDeviceIDChange() async throws {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        var value = await dataStore.isAppRestore
        #expect(!(value))


        await self.testDeviceID.setValue(value: UUID().uuidString)
        value = await dataStore.isAppRestore
        #expect(value)
    }

    @Test
    func testKeyIsStoredAndRetrieved() {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )

        let value = ProcessInfo.processInfo.globallyUniqueString
        dataStore.setObject(value, forKey: "key")
        #expect(dataStore.string(forKey: "key") == value)
    }

    @Test
    func testKeyIsRemoved() {
        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )

        let value = ProcessInfo.processInfo.globallyUniqueString
        dataStore.setObject(value, forKey: "key")
        #expect(dataStore.object(forKey: "key") as? String == value)
        dataStore.removeObject(forKey: "key")
        #expect(dataStore.object(forKey: "key") == nil)
    }

    @Test
    func testMigration() {
        let prefix = UUID().uuidString
        UserDefaults.standard.set(true, forKey: "\(prefix)some-key")

        let dataStore = PreferenceDataStore(
            appKey: prefix,
            deviceID: testDeviceID
        )

        #expect(dataStore.bool(forKey: "some-key"))
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
