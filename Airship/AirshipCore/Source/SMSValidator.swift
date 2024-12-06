/* Copyright Airship and Contributors */

import Foundation

protocol SMSValidatorProtocol: Sendable {
    var delegate: (any SMSValidatorDelegate)? { get set }

    func validateSMS(msisdn: String, sender: String) async throws -> Bool
}

/// Delegate for overriding the default SMS validation
public protocol SMSValidatorDelegate: Sendable {

    /**
     * Validates a given MSISDN.
     * - Parameters:
     *   - msisdn: The msisdn to validate.
     *   - sender: The identifier given to the sender of the SMS message.
     * - Returns: `true` if the phone number is valid, otherwise `false`.
     */
    @MainActor
    func validateSMS(msisdn: String, sender: String) async throws -> Bool
}

struct SMSValidationResult: Decodable {
    let ok: Bool
    let valid: Bool
}

/// NOTE: For internal use only. :nodoc:
protocol SMSValidatorAPIClientProtocol: Sendable {
    func validateSMS(
        msisdn: String,
        sender: String
    ) async throws ->  AirshipHTTPResponse<Bool>
}

class SMSValidator: SMSValidatorProtocol, @unchecked Sendable {
    let apiClient: any SMSValidatorAPIClientProtocol
    var delegate: (any SMSValidatorDelegate)?

    /// Stores up to 10 most recent SMS validation results.
    private var resultsCache: [String] = []
    private var resultsLookup: [String: Bool] = [:]

    init(apiClient: any SMSValidatorAPIClientProtocol, delegate: (any SMSValidatorDelegate)? = nil) {
        self.apiClient = apiClient
        Task { @MainActor in
            self.delegate = delegate
        }
    }

    private func cacheResult(key: String, result: Bool) {
        if resultsCache.count >= 10 {
            let oldestKey = resultsCache.removeFirst()
            resultsLookup.removeValue(forKey: oldestKey)
        }
        resultsCache.append(key)
        resultsLookup[key] = result
    }

    private func hasCachedResult(key: String) -> Bool? {
        return resultsLookup[key]
    }

    @MainActor
    func validateSMS(msisdn: String, sender: String) async throws -> Bool {
        let compoundKey = sender + msisdn

        if let cachedResult = hasCachedResult(key: compoundKey) {
            return cachedResult
        }

        if let delegate = delegate {
            let isValid = try await delegate.validateSMS(msisdn: msisdn, sender: sender)
            cacheResult(key: compoundKey, result: isValid)
            return isValid
        }

        let response = try await apiClient.validateSMS(msisdn: msisdn, sender: sender)
        guard let isValid = response.result else {
            throw AirshipErrors.error("Response result from SMS validation API should not be nil.")
        }

        cacheResult(key: compoundKey, result: isValid)
        return isValid
    }
}

/// NOTE: For internal use only. :nodoc:
final class SMSValidatorAPIClient: SMSValidatorAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            guard let date = AirshipDateFormatter.date(fromISOString: dateStr) else {
                throw AirshipErrors.error("Invalid date \(dateStr)")
            }
            return date
        })
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom({ date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(
                AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter)
            )
        })
        return encoder
    }

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
    ) async throws -> AirshipHTTPResponse<Bool> {
        return try await performSMSValidation(
            requestBody: SMSValidationBody(
                sender: sender,
                msisdn: msisdn
            ),
            channelType: ChannelType.sms
        )
    }

    fileprivate func performSMSValidation<T: Encodable>(
        requestBody: T,
        channelType: ChannelType
    ) async throws -> AirshipHTTPResponse<Bool> {
        let request = AirshipRequest(
            url: try makeURL(path: "/api/channels/sms/validate"),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: try self.encoder.encode(requestBody)
        )

        let decoder = self.decoder
        return try await self.session.performHTTPRequest(
            request
        ) { (data, response) in
            AirshipLogger.debug(
                "SMS Channel validation finished with response: \(response)"
            )

            guard let data = data, response.statusCode >= 200, response.statusCode < 300 else {
                throw AirshipErrors.error("Invalid request made in performSMSValidation")
            }

            let result = try decoder.decode(SMSValidationResult.self, from: data)

            return result.valid
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
}

fileprivate struct SMSValidationBody: Encodable {
    let sender: String
    let msisdn: String

    init(
        sender: String,
        msisdn: String
    ) {
        self.sender = sender
        self.msisdn = msisdn
    }

    enum CodingKeys: String, CodingKey {
        case sender = "sender"
        case msisdn = "msisdn"
    }
}
