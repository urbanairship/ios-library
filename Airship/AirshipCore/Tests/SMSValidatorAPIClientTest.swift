/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class SMSValidatorAPIClientTest: XCTestCase {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private var smsValidatorAPIClient: SMSValidatorAPIClient!
    private var config: RuntimeConfig!
    private let currentLocale = Locale(identifier: "fr-CA")

    override func setUpWithError() throws {
        var airshipConfig = AirshipConfig()
        airshipConfig.deviceAPIURL = "https://example.com"
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://contacts_test")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.smsValidatorAPIClient = SMSValidatorAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testValidateSMS() async throws {

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://example.com/api/channels/sms/validate")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.session.data = """
            {
                "ok": true,
                "valid" : true
            }
            """
            .data(using: .utf8)

        let response = try await smsValidatorAPIClient.validateSMS(
            msisdn: "18222111000",
            sender: "14222111000"
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.result)
        XCTAssertTrue(response.result!)

        let lastRequest = self.session.lastRequest!
        XCTAssertNotNil(lastRequest)
        XCTAssertEqual(
            "https://example.com/api/channels/sms/validate",
            lastRequest.url!.absoluteString
        )

        let lastBody = try JSONSerialization.jsonObject(
            with: lastRequest.body!,
            options: []
        )
        let lastExpectedBody: Any = [
            "msisdn": "18222111000",
            "sender": "14222111000"
        ]
        XCTAssertEqual(
            lastBody as! NSDictionary,
            lastExpectedBody as! NSDictionary
        )
    }
}
