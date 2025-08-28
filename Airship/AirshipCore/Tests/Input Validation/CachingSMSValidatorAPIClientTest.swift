/* Copyright Airship and Contributors */

import Testing


@testable import AirshipCore

struct CachingSMSValidatorAPIClientTest {
    private let testClient: TestSMSValidatorAPIClient
    private let apiClient: CachingSMSValidatorAPIClient
    private static let maxCacheEntries: UInt = 5

    init() {
        let testClient = TestSMSValidatorAPIClient()
        self.testClient = testClient
        self.apiClient = CachingSMSValidatorAPIClient(
            client: testClient,
            maxCachedEntries: Self.maxCacheEntries
        )
    }

    @Test("Test caches success results for prefix")
    func testCachesSuccessResultsPrefix() async throws {
        let successResult = AirshipHTTPResponse(
            result: SMSValidatorAPIClientResult.valid("valid string"),
            statusCode: 200,
            headers: [:]
        )

        await testClient.setOnValidate { _ in
            return successResult
        }

        let msisdn = UUID().uuidString
        let prefix = UUID().uuidString

        var result = try await self.apiClient.validateSMS(msisdn: msisdn, prefix: prefix)
        #expect(result.isSuccess)
        #expect(result.result == successResult.result)
        await #expect(testClient.requests.count == 1)

        // Should be cached
        result = try await self.apiClient.validateSMS(msisdn: msisdn, prefix: prefix)
        #expect(result.isSuccess)
        #expect(result.result == successResult.result)
        await #expect(testClient.requests.count == 1)
    }

    @Test("Test caches success results for sender")
    func testCachesSuccessResultsSender() async throws {
        let successResult = AirshipHTTPResponse(
            result: SMSValidatorAPIClientResult.valid("valid string"),
            statusCode: 200,
            headers: [:]
        )

        await testClient.setOnValidate { _ in
            return successResult
        }

        let msisdn = UUID().uuidString
        let sender = UUID().uuidString

        var result = try await self.apiClient.validateSMS(msisdn: msisdn, prefix: sender)
        #expect(result.isSuccess)
        #expect(result.result == successResult.result)
        await #expect(testClient.requests.count == 1)

        // Should be cached
        result = try await self.apiClient.validateSMS(msisdn: msisdn, prefix: sender)
        #expect(result.isSuccess)
        #expect(result.result == successResult.result)
        await #expect(testClient.requests.count == 1)
    }

    @Test("Test caches results for the given parameters even for same msisdn")
    func testCachesResultForRequestParams() async throws {
        await testClient.setOnValidate { call in
            return AirshipHTTPResponse(
                result: SMSValidatorAPIClientResult.valid(call.msisdn + " valid"),
                statusCode: 200,
                headers: [:]
            )
        }

        let msisdn = UUID().uuidString
        let prefix = UUID().uuidString
        let sender = UUID().uuidString

        var result = try await self.apiClient.validateSMS(msisdn: msisdn, prefix: prefix)
        #expect(result.isSuccess)
        #expect(result.result == .valid(msisdn + " valid"))
        await #expect(testClient.requests.count == 1)

        // Should not be cached since we are requesting the validation on a sender instead of a prefix
        result = try await self.apiClient.validateSMS(msisdn: msisdn, sender: sender)
        #expect(result.isSuccess)
        #expect(result.result == .valid(msisdn + " valid"))
        await #expect(testClient.requests.count == 2)

        let expectedRequests: [TestSMSValidatorAPIClient.Request] = [
            .init(msisdn: msisdn, prefix: prefix),
            .init(msisdn: msisdn, sender: sender)
        ]
        await #expect(testClient.requests == expectedRequests)
    }

    @Test("Test max cache entries")
    func testMaxCacheEntries() async throws {
        await testClient.setOnValidate { call in
            return AirshipHTTPResponse(
                result: SMSValidatorAPIClientResult.valid(call.msisdn + " valid"),
                statusCode: 200,
                headers: [:]
            )
        }

        // Fill the cache
        for i in 1...Self.maxCacheEntries {
            print("cool i: \(i)")
            _ = try await self.apiClient.validateSMS(
                msisdn: UUID().uuidString,
                prefix: UUID().uuidString
            )
        }

        await #expect(testClient.requests.count == Self.maxCacheEntries)

        _ = try await self.apiClient.validateSMS(
            msisdn: UUID().uuidString,
            prefix: UUID().uuidString
        )

        await #expect(testClient.requests.count == Self.maxCacheEntries + 1)

        // Do the second request again, should still be cached
        _ = try await self.apiClient.validateSMS(
            msisdn: testClient.requests[1].msisdn,
            prefix: testClient.requests[1].prefix!
        )

        await #expect(testClient.requests.count == Self.maxCacheEntries + 1)
    }
}
