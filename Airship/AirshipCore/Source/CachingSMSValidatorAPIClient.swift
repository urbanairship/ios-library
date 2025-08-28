/* Copyright Airship and Contributors */

actor CachingSMSValidatorAPIClient: SMSValidatorAPIClientProtocol {
    private struct CacheEntry: Sendable, Equatable{
        let msisdn: String
        let sender: String?
        let prefix: String?
        let result: AirshipHTTPResponse<SMSValidatorAPIClientResult>
    }

    private let client: any SMSValidatorAPIClientProtocol
    private var cache: [CacheEntry] = []
    private let maxCachedEntries: UInt

    init(
        client: any SMSValidatorAPIClientProtocol,
        maxCachedEntries: UInt = 10
    ) {
        self.client = client
        self.maxCachedEntries = maxCachedEntries
    }

    func validateSMS(msisdn: String, sender: String) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        let result = if let cached = cachedResult(msisdn: msisdn, sender: sender) {
            cached
        } else {
            try await client.validateSMS(msisdn: msisdn, sender: sender)
        }

        cacheResult(result, msisdn: msisdn, prefix: nil, sender: sender)

        return result
    }

    func validateSMS(msisdn: String, prefix: String) async throws -> AirshipHTTPResponse<SMSValidatorAPIClientResult> {
        let result = if let cached = cachedResult(msisdn: msisdn, prefix: prefix) {
            cached
        } else {
            try await client.validateSMS(msisdn: msisdn, prefix: prefix)
        }

        cacheResult(result, msisdn: msisdn, prefix: prefix, sender: nil)
        return result
    }

    private func cachedResult(msisdn: String, sender: String) -> AirshipHTTPResponse<SMSValidatorAPIClientResult>? {
        return cache.first { entry in
            entry.msisdn == msisdn && entry.sender == sender
        }?.result
    }

    private func cachedResult(msisdn: String, prefix: String) -> AirshipHTTPResponse<SMSValidatorAPIClientResult>? {
        return cache.first { entry in
            entry.msisdn == msisdn && entry.prefix == prefix
        }?.result
    }

    private func cacheResult(
        _ result: AirshipHTTPResponse<SMSValidatorAPIClientResult>,
        msisdn: String,
        prefix: String?,
        sender: String?
    ) {
        guard result.isSuccess else { return }

        let entry = CacheEntry(
            msisdn: msisdn,
            sender: sender,
            prefix: prefix,
            result: result
        )

        cache.removeAll { $0 == entry }

        cache.append(
            entry
        )

        if cache.count > self.maxCachedEntries {
            cache.remove(at: 0)
        }
    }
}
