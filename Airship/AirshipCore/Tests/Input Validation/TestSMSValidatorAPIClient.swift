/* Copyright Airship and Contributors */

@testable import AirshipCore

actor TestSMSValidatorAPIClient: SMSValidatorAPIClientProtocol {
    struct Request: Sendable, Equatable {
        var msisdn: String
        var sender: String?
        var prefix: String?
    }

    private var onValidate: ((Request) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult>)?

    func setOnValidate(_ onValidate: ((Request) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult>)?) {
        self.onValidate = onValidate
    }

    private(set) var requests: [Request] = []

    func validateSMS(msisdn: String, sender: String) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        let request = Request(msisdn: msisdn, sender: sender)
        self.requests.append(request)
        guard let onValidate else {
            throw AirshipErrors.error("Validator not set")
        }
        return try await onValidate(request)
    }

    func validateSMS(msisdn: String, prefix: String) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        let request = Request(msisdn: msisdn, prefix: prefix)
        self.requests.append(request)
        guard let onValidate else {
            throw AirshipErrors.error("Validator not set")
        }
        return try await onValidate(request)
    }
}
