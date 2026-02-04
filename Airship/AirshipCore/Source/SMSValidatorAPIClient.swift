/* Copyright Airship and Contributors */

import Foundation

enum SMSValidatorAPIClientResult: Decodable, Equatable, Sendable {
    case valid(String)
    case invalid

    enum CodingKeys: CodingKey {
        case valid
        case msisdn
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if try container.decode(Bool.self, forKey: .valid) {
            let msisdn = try container.decode(String.self, forKey: .msisdn)
            self = .valid(msisdn)
        } else {
            self = .invalid
        }
    }
}

protocol SMSValidatorAPIClientProtocol: Sendable {
    func validateSMS(
        msisdn: String,
        sender: String
    ) async throws ->  AirshipHTTPResponse<SMSValidatorAPIClientResult>

    func validateSMS(
        msisdn: String,
        prefix: String
    ) async throws ->  AirshipHTTPResponse<SMSValidatorAPIClientResult>
}

final class SMSValidatorAPIClient: SMSValidatorAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    init(config: RuntimeConfig, session: any AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }

    func validateSMS(
        msisdn: String,
        sender: String
    ) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        return try await performSMSValidation(
            requestBody: RequestBody(
                msisdn: msisdn,
                sender: sender,
                prefix: nil
            )
        )
    }

    func validateSMS(
        msisdn: String,
        prefix: String
    ) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        return try await performSMSValidation(
            requestBody: RequestBody(
                msisdn: msisdn,
                sender: nil,
                prefix: prefix
            )
        )
    }

    fileprivate func performSMSValidation<T: Encodable>(
        requestBody: T
    ) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        let request = AirshipRequest(
            url: try makeURL(path: "/api/channels/sms/format"),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: try JSONEncoder().encode(requestBody)
        )

        return try await self.session.performHTTPRequest(
            request
        ) { (data, response) in
            AirshipLogger.debug(
                "SMS validation finished with response: \(response)"
            )

            guard let data = data, response.statusCode >= 200, response.statusCode < 300 else {
                throw AirshipErrors.error("Invalid request made in performSMSValidation")
            }

            return try JSONDecoder().decode(SMSValidatorAPIClientResult.self, from: data)
        }
    }

    private func makeURL(path: String) throws -> URL {
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("Initial config not resolved.")
        }

        let urlString = "\(deviceAPIURL)\(path)"

        guard let url = URL(string: "\(deviceAPIURL)\(path)") else {
            throw AirshipErrors.error("Invalid ContactAPIClient URL: \(String(describing: urlString))")
        }

        return url
    }

    fileprivate struct RequestBody: Encodable {
        let msisdn: String
        let sender: String?
        let prefix: String?

        enum CodingKeys: String, CodingKey {
            case msisdn
            case sender
            case prefix
        }
    }
}


