/* Copyright Airship and Contributors */

import AirshipCore
import XCTest

@testable import AirshipPreferenceCenter

class PreferenceCenterTest: XCTestCase {

    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var privacyManager: TestPrivacyManager!
    private var preferenceCenter: DefaultAirshipPreferenceCenter!
    private let remoteDataProvider: TestRemoteData = TestRemoteData()

    override func setUp() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all
        )
        
        self.preferenceCenter = await DefaultAirshipPreferenceCenter(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            remoteData: self.remoteDataProvider,
            inputValidator: TestInputValidator()
        )
    }

    func testConfig() async throws {
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
        self.remoteDataProvider.payloads = [remoteData]

        var config = try! await self.preferenceCenter.config(preferenceCenterID: "form-1")
        XCTAssertEqual("form-1", config.identifier)

        config = try! await self.preferenceCenter.config(preferenceCenterID: "form-2")
        XCTAssertEqual("form-2", config.identifier)
    }

    func testJSONConfig() async throws {
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
        self.remoteDataProvider.payloads = [remoteData]

        let config1 = try! await self.preferenceCenter.jsonConfig(preferenceCenterID: "form-1")

        XCTAssertEqual(
            try! AirshipJSON.from(data: config1),
            try! AirshipJSON.wrap(["id": "form-1"])
        )

        let config2 = try! await self.preferenceCenter.jsonConfig(preferenceCenterID: "form-2")
        XCTAssertEqual(
            try! AirshipJSON.from(data: config2),
            try! AirshipJSON.wrap(["id": "form-2"])
        )
    }

    @MainActor
      func testOnDisplay() async throws {
          let delegate = MockPreferenceCenterOpenDelegate()
          self.preferenceCenter.openDelegate = delegate

          let expectation = self.expectation(description: "onDisplay called")
          self.preferenceCenter.onDisplay = { identifier in
              XCTAssertEqual("some-form", identifier)
              expectation.fulfill()
              return true // Handle the display
          }

          self.preferenceCenter.display(identifier: "some-form")

          await self.fulfillment(of: [expectation], timeout: 1.0)

          XCTAssertFalse(delegate.openCalled)
      }

      @MainActor
      func testOnDisplayNilFallback() async throws {
          let delegate = MockPreferenceCenterOpenDelegate()
          self.preferenceCenter.openDelegate = delegate
          self.preferenceCenter.onDisplay = nil

          self.preferenceCenter.display(identifier: "some-form")
          XCTAssertEqual("some-form", delegate.lastOpenID)
      }

    @MainActor
    func testDeepLink() async throws {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate

        let valid = URL(string: "uairship://preferences/some-id")!
        XCTAssertTrue(self.preferenceCenter.deepLink(valid))
        
        XCTAssertEqual("some-id", delegate.lastOpenID)

        let trailingSlash = URL(
            string: "uairship://preferences/some-other-id/"
        )!
        XCTAssertTrue(self.preferenceCenter.deepLink(trailingSlash))
        
        XCTAssertEqual("some-other-id", delegate.lastOpenID)
    }

    @MainActor
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
        return RemoteDataPayload(
            type: "preference_forms",
            timestamp: Date(),
            data: try! AirshipJSON.from(json: json),
            remoteDataInfo: nil
        )
    }
}

fileprivate final class TestInputValidator: AirshipInputValidation.Validator {
    func validateRequest(_ request: AirshipCore.AirshipInputValidation.Request) async throws -> AirshipCore.AirshipInputValidation.Result {
        return .invalid
    }
}


@MainActor
fileprivate class MockPreferenceCenterOpenDelegate: PreferenceCenterOpenDelegate {
    var lastOpenID: String?
    var openCalled: Bool = false

    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool {
        self.lastOpenID = preferenceCenterID
        self.openCalled = true
        return true
    }
}
