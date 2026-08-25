/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct PreferenceDataStoreTest {

    private static let airshipSuiteName =
        "\(Bundle.main.bundleIdentifier ?? "").airship.settings"
    private let airshipDefaults = UserDefaults(
        suiteName: PreferenceDataStoreTest.airshipSuiteName
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

    /// Migrating out of the standard defaults is a one-time repair for
    /// SDK 15.x-16.0.1. Once it has run for an app key, later launches must not
    /// scan or copy anything.
    @Test
    func testStandardDefaultsMigrationRunsOnce() {
        UserDefaults.standard.set("first", forKey: "\(self.appKey)first-key")

        let first = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        #expect(first.string(forKey: "first-key") == "first")
        first.waitForWrites()

        // A key that lands in the standard defaults after the migration already
        // completed. A later launch must leave it where it is.
        let lateKey = "\(self.appKey)second-key"
        UserDefaults.standard.set("second", forKey: lateKey)

        let second = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        #expect(second.string(forKey: "second-key") == nil)
        #expect(UserDefaults.standard.string(forKey: lateKey) == "second")

        UserDefaults.standard.removeObject(forKey: lateKey)
    }

    /// The same for the second scan, which merges legacy keys already sitting in
    /// the Airship suite.
    @Test
    func testMergeKeysRunsOnce() {
        let legacyKey = "com.urbanairship.\(self.appKey).late-key"

        let first = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        first.waitForWrites()

        self.airshipDefaults.set("late", forKey: legacyKey)

        let second = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        #expect(second.string(forKey: "late-key") == nil)

        // The old key is left untouched, proving the merge never ran.
        #expect(self.airshipDefaults.string(forKey: legacyKey) == "late")

        self.airshipDefaults.removeObject(forKey: legacyKey)
    }

    /// The completion flag is scoped per app key, so an app key that has never
    /// migrated still does so even after another one has finished.
    @Test
    func testMigrationRunsOncePerAppKey() {
        let otherAppKey = UUID().uuidString
        UserDefaults.standard.set("a", forKey: "\(self.appKey)shared-key")
        UserDefaults.standard.set("b", forKey: "\(otherAppKey)shared-key")

        let first = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        #expect(first.string(forKey: "shared-key") == "a")
        first.waitForWrites()

        let second = PreferenceDataStore(
            appKey: otherAppKey,
            deviceID: testDeviceID
        )
        #expect(second.string(forKey: "shared-key") == "b")
    }

    /// The scan only covers the app's own preferences domain. Registered defaults
    /// live in the registration domain, which `removeObject(forKey:)` cannot clear,
    /// so copying from there would repeat on every launch forever.
    @Test
    func testMigrationIgnoresRegisteredDefaults() {
        let registeredKey = "\(self.appKey)registered-key"
        UserDefaults.standard.register(
            defaults: [registeredKey: "registered-value"]
        )

        let dataStore = PreferenceDataStore(
            appKey: self.appKey,
            deviceID: testDeviceID
        )
        dataStore.waitForWrites()

        // Checked against the suite's persistent domain rather than
        // `object(forKey:)`, which falls through to the process-wide registration
        // domain and would report the value whether or not it was copied.
        let persisted = self.airshipDefaults.persistentDomain(
            forName: PreferenceDataStoreTest.airshipSuiteName
        )
        #expect(persisted?[registeredKey] == nil)
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
