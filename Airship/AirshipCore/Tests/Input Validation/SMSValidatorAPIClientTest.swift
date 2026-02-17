/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

struct SMSValidatorAPIClientTest {

    private let session: TestAirshipRequestSession
    private let config: RuntimeConfig
    private let apiClient: SMSValidatorAPIClient

    private let msisdn = UUID().uuidString
    private let sender = UUID().uuidString
    private let prefix = UUID().uuidString

    init() {
        let config = RuntimeConfig.testConfig()
        let session = TestAirshipRequestSession()
        self.session = session
        self.config = RuntimeConfig.testConfig()
        self.apiClient = SMSValidatorAPIClient(config: config, session: session)
    }

    @Test("Test validate SMS with sender")
    func testSendSMSWithSender() async throws {
        let expectedRequest = AirshipRequest(
            url: URL(string: "https://device-api.urbanairship.com/api/channels/sms/format"),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: try JSONEncoder().encode(
                [
                    "msisdn": msisdn,
                    "sender": sender
                ]
            )
        )

        _ = try? await apiClient.validateSMS(
            msisdn: msisdn,
            sender: sender
        )

        #expect(
            try requestsMatch(expectedRequest, session.lastRequest)
        )
    }

    @Test("Test validate SMS with prefix")
    func testSendSMSWithPrefix() async throws {

        let expectedRequest = AirshipRequest(
            url: URL(string: "https://device-api.urbanairship.com/api/channels/sms/format"),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: try JSONEncoder().encode(
                [
                    "msisdn": msisdn,
                    "prefix": prefix
                ]
            )
        )

        _ = try? await apiClient.validateSMS(
            msisdn: msisdn,
            prefix: prefix
        )

        #expect(
            try requestsMatch(expectedRequest, session.lastRequest)
        )
    }

    @Test("Test valid number response parsing.")
    func testResponseParsing() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.session.data = try AirshipJSONUtils.data([
            "valid": true,
            "msisdn": msisdn + "valid"
        ])

        let response = try await apiClient.validateSMS(
            msisdn: msisdn,
            sender: sender
        )

        #expect(response.isSuccess)
        #expect(response.result == .valid(msisdn + "valid"))
    }

    @Test("Test invalid number response parsing.")
    func testResponseParsingInvalidNumber() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.session.data = try AirshipJSONUtils.data([
            "valid": false
        ])

        let response = try await apiClient.validateSMS(
            msisdn: msisdn,
            sender: sender
        )

        #expect(response.isSuccess)
        #expect(response.result == .invalid)
    }

    private func requestsMatch(
        _ first: AirshipRequest,
        _ second: AirshipRequest?
    ) throws -> Bool {
        guard
            let second,
            first.auth == second.auth,
            first.contentEncoding == second.contentEncoding,
            first.headers ==  second.headers,
            first.url == second.url,
            first.method == second.method
        else {
            return false
        }

        let firstBody = try AirshipJSON.from(data: first.body)
        let secondBody = try AirshipJSON.from(data: second.body)
        return firstBody == secondBody
    }

}
