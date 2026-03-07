/* Copyright Airship and Contributors */

import Testing
import AirshipCore
import Foundation

@testable
import AirshipPreferenceCenter

@Suite("Preference Center")
struct PreferenceCenterTest {
    
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var privacyManager: TestPrivacyManager!
    private var preferenceCenter: DefaultPreferenceCenter!
    private let remoteDataProvider: TestRemoteData = TestRemoteData()
    
    init() async {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all
        )
        
        self.preferenceCenter = await DefaultPreferenceCenter(
            dataStore: self.dataStore,
            privacyManager: self.privacyManager,
            remoteData: self.remoteDataProvider,
            inputValidator: TestInputValidator()
        )
    }
    
    @Test("Json config", arguments: ["form-1", "form-2"])
    func config(id: String) async throws {
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
        
        var config = try! await self.preferenceCenter.config(preferenceCenterID: id)
        #expect(id == config.identifier)
    }
    
    @Test("Json config", arguments: ["form-1", "form-2"])
    func jsonConfig(id: String) async throws {
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
        
        let config = try! await self.preferenceCenter.jsonConfig(preferenceCenterID: id)
        
        let jsonConfig = try! AirshipJSON.from(data: config)
        let jsonform = try! AirshipJSON.wrap(["id": id])
        #expect(jsonConfig == jsonform)
    }
    
    @MainActor
    @Test("Ensure preference center displays the correct form")
    func onDisplay() async throws {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate
        
        await confirmation("onDisplay called", expectedCount: 1) { confirm in
            
            self.preferenceCenter.onDisplay = { identifier in
                #expect(identifier == "some-form")
                confirm()
                return true
            }
            
            self.preferenceCenter.display("some-form")
        }
        #expect(!delegate.openCalled)
    }
    
    @MainActor
    @Test
    func onDisplayNilFallback() async throws {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate
        self.preferenceCenter.onDisplay = nil
        
        self.preferenceCenter.display("some-form")
        #expect("some-form" == delegate.lastOpenID)
    }
    
    @MainActor
    @Test
    func deepLink() async throws {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate
        
        let valid = URL(string: "uairship://preferences/some-id")!
        #expect(self.preferenceCenter.deepLink(valid))
        
        #expect("some-id" == delegate.lastOpenID)
        
        let trailingSlash = URL(
            string: "uairship://preferences/some-other-id/"
        )!
        #expect(self.preferenceCenter.deepLink(trailingSlash))
        
        #expect("some-other-id" == delegate.lastOpenID)
    }
    
    @MainActor
    @Test
    func deepLinkInvalid() {
        let delegate = MockPreferenceCenterOpenDelegate()
        self.preferenceCenter.openDelegate = delegate
        
        let wrongScheme = URL(string: "whatever://preferences/some-id")!
        #expect(!self.preferenceCenter.deepLink(wrongScheme))
        
        let wrongHost = URL(string: "uairship://message_center/some-id")!
        #expect(!self.preferenceCenter.deepLink(wrongHost))
        
        let tooManyArgs = URL(
            string: "uairship://preferences/some-other-id/what"
        )!
        #expect(!self.preferenceCenter.deepLink(tooManyArgs))
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
