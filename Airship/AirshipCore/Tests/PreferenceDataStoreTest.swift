/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class PreferenceDataStoreTest: XCTestCase {

    let airshipDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier ?? "").airship.settings")!
    let appKey = UUID().uuidString
    
    func testPrefix() throws {
        let dataStore = PreferenceDataStore(appKey: self.appKey)
        dataStore.setObject("neat", forKey: "some-key")
        XCTAssertEqual("neat", airshipDefaults.string(forKey: "\(self.appKey)some-key"))
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
        self.airshipDefaults.set("keep-new: new", forKey: "\(newPrefix)keep-new")
        standardDefaults.set("restore-old: old", forKey: "\(legacyPrefix)restore-old")
        
        self.airshipDefaults.set("another-keep-new: old", forKey: "\(legacyPrefix)another-keep-new")
        self.airshipDefaults.set("another-keep-new: new", forKey: "\(newPrefix)another-keep-new")
        self.airshipDefaults.set("another-restore-old: old", forKey: "\(legacyPrefix)another-restore-old")
        
        
        standardDefaults.set(["a", "b"], forKey: "\(legacyPrefix)\(tagsKey)")
        self.airshipDefaults.set(["c"], forKey: "\(newPrefix)\(tagsKey)")
        
        let dataStore = PreferenceDataStore(appKey: self.appKey)

        XCTAssertEqual("another-keep-new: new", dataStore.string(forKey: "another-keep-new"))
        XCTAssertEqual("another-restore-old: old", dataStore.string(forKey: "another-restore-old"))
        XCTAssertEqual("keep-new: new", dataStore.string(forKey: "keep-new"))
        XCTAssertEqual("restore-old: old", dataStore.string(forKey: "restore-old"))
        XCTAssertEqual(["a", "b", "c"], dataStore.stringArray(forKey: tagsKey))
    }
}
