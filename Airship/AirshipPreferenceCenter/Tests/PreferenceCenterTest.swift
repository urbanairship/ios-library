/* Copyright Airship and Contributors */

import AirshipCore
import XCTest

@testable import AirshipPreferenceCenter

class PreferenceCenterTest: XCTestCase {

    private var dataStore: PreferenceDataStore!
    private var privacyManager: AirshipPrivacyManager!
    private var preferenceCenter: PreferenceCenter!
    private var remoteDataProvider: MockRemoteDataProvider!

    override func setUp() {
        self.remoteDataProvider = MockRemoteDataProvider()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            defaultEnabledFeatures: .all
        )

        self.preferenceCenter = PreferenceCenter(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            remoteDataProvider: self.remoteDataProvider
        )
    }

    func testConfig() throws {
        let payloadData = """
            {
               "preference_forms":[
                  {
                     "created":"2017-10-10T12:13:14.023",
                     "last_updated":"2017-10-10T12:13:14.023",
                     "form_id":"031de218-9fff-44d4-b348-de4b724bb924",
                     "form":{
                        "id":"form-1",
                        "sections":[]
                     }
                  },
                  {
                     "created":"2018-10-10T12:13:14.023",
                     "last_updated":"2018-10-10T12:13:14.023",
                     "form_id":"031de218-9fff-44d4-b348-de4b724bb931",
                     "form":{
                        "id":"form-2",
                        "sections":[]
                     }
                  }
               ]
            }
            """

        let remoteData = createPayload(payloadData)

        let form1Expectation = XCTestExpectation(description: "form-1")
        self.preferenceCenter.config(preferenceCenterID: "form-1") { config in
            XCTAssertNotNil(config)
            XCTAssertEqual("form-1", config?.identifier)
            form1Expectation.fulfill()
        }

        let form2Expectation = XCTestExpectation(description: "form-2")
        self.preferenceCenter.config(preferenceCenterID: "form-2") { config in
            XCTAssertNotNil(config)
            XCTAssertEqual("form-2", config?.identifier)
            form2Expectation.fulfill()
        }

        let missingFormExpectation = XCTestExpectation(description: "missing")
        self.preferenceCenter.config(preferenceCenterID: "missing") { config in
            XCTAssertNil(config)
            missingFormExpectation.fulfill()
        }

        self.remoteDataProvider.dispatchPayload(remoteData)
        self.wait(
            for: [form1Expectation, form2Expectation, missingFormExpectation],
            timeout: 5
        )
    }

    func testJSONConfig() throws {
        let payloadData = """
            {
               "preference_forms":[
                  {
                     "created":"2017-10-10T12:13:14.023",
                     "last_updated":"2017-10-10T12:13:14.023",
                     "form_id":"031de218-9fff-44d4-b348-de4b724bb924",
                     "form":{
                        "id":"form-1"
                     }
                  },
                  {
                     "created":"2018-10-10T12:13:14.023",
                     "last_updated":"2018-10-10T12:13:14.023",
                     "form_id":"031de218-9fff-44d4-b348-de4b724bb931",
                     "form":{
                        "id":"form-2"
                     }
                  }
               ]
            }
            """

        let remoteData = createPayload(payloadData)
        var expectedConfig: [String: Any] = [:]
        expectedConfig.updateValue("form-1", forKey: "id")

        let form1Expectation = XCTestExpectation(description: "form-1")
        self.preferenceCenter.jsonConfig(preferenceCenterID: "form-1") {
            config in
            XCTAssertNotNil(config)
            XCTAssertTrue(
                NSDictionary(dictionary: config).isEqual(to: expectedConfig)
            )
            form1Expectation.fulfill()
        }

        var expectedConfig2: [String: Any] = [:]
        expectedConfig2.updateValue("form-2", forKey: "id")

        let form2Expectation = XCTestExpectation(description: "form-2")
        self.preferenceCenter.jsonConfig(preferenceCenterID: "form-2") {
            config in
            XCTAssertNotNil(config)
            XCTAssertTrue(
                NSDictionary(dictionary: config).isEqual(to: expectedConfig2)
            )
            form2Expectation.fulfill()
        }

        self.remoteDataProvider.dispatchPayload(remoteData)
        self.wait(for: [form1Expectation, form2Expectation], timeout: 5)
    }

    func testOpenDelegate() {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate
        self.preferenceCenter.open("some-form")
        XCTAssertEqual("some-form", delegate.lastOpenId)
    }

    func testDeepLink() {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate

        let valid = URL(string: "uairship://preferences/some-id")!
        XCTAssertTrue(self.preferenceCenter.deepLink(valid))
        XCTAssertEqual("some-id", delegate.lastOpenId)

        let trailingSlash = URL(
            string: "uairship://preferences/some-other-id/"
        )!
        XCTAssertTrue(self.preferenceCenter.deepLink(trailingSlash))
        XCTAssertEqual("some-other-id", delegate.lastOpenId)
    }

    func testDeepLinkInvalid() {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate

        let wrongScheme = URL(string: "whatever://preferences/some-id")!
        XCTAssertFalse(self.preferenceCenter.deepLink(wrongScheme))

        let wrongHost = URL(string: "uairship://message_center/some-id")!
        XCTAssertFalse(self.preferenceCenter.deepLink(wrongHost))

        let tooManyArgs = URL(
            string: "uairship://preferences/some-other-id/what"
        )!
        XCTAssertFalse(self.preferenceCenter.deepLink(tooManyArgs))
    }

    private func createPayload(_ json: String) -> RemoteDataPayload {
        let data =
            try! JSONSerialization.jsonObject(
                with: json.data(using: .utf8)!,
                options: []
            ) as! [AnyHashable: Any]

        return RemoteDataPayload(
            type: "preference_forms",
            timestamp: Date(),
            data: data,
            metadata: [:]
        )
    }
}
