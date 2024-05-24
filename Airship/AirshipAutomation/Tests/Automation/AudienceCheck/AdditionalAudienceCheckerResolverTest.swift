/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

class AdditionalAudienceCheckerResolverTest: XCTestCase {
    
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let date = UATestDate(dateOverride: Date())
    private let apiClient = TestAudienceApiClient()
    private var cache: AirshipCache!
    
    private var resolver: AdditionalAudienceCheckerResolver!
    private var deviceInfoProvider: TestDeviceInfoProvider = TestDeviceInfoProvider()

    private let defaultAudienceConfig = RemoteConfig.AdditionalAudienceCheckConfig(
        isEnabled: true,
        context: .string("remote config context"),
        url: "https://test.config")
    
    override func setUp() async throws {
        cache = TestAirshipCoreDataCache.makeCache(date: date)
    }
    
    func testHappyPath() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        deviceInfoProvider.stableContactInfo = StableContactInfo(contactID: "existing-contact-id", namedUserID: "some user id")
        deviceInfoProvider.channelID = "channel-id"

        apiClient.onResponse = { request in
            XCTAssertEqual("channel-id", request.channelID)
            XCTAssertEqual("existing-contact-id", request.contactID)
            XCTAssertEqual("some user id", request.namedUserID)
            XCTAssertEqual(AirshipJSON.string("default context"), request.context)
            XCTAssertEqual("https://test.config", request.url.absoluteString)
            
            return AirshipHTTPResponse.make(
                result: AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 10),
                statusCode: 200,
                headers: [:])
        }
        
        let cacheKey = "https://test.config:\"default context\":existing-contact-id:channel-id"
        
        var cached: AdditionalAudienceCheckResult? = await cache.getCachedValue(key: cacheKey)
        XCTAssertNil(cached)
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil)
        )

        cached = await cache.getCachedValue(key: cacheKey)
        XCTAssertEqual(true, cached?.isMatched)
        XCTAssertEqual(10, cached?.cacheTTL)
        XCTAssert(result)
    }
    
    func testResolverReturnsTrueOnNoConfigOrDisabled() async throws {
        makeResolver(config: nil)
        
        var result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil
            )
        )

        XCTAssert(result)
        
        makeResolver(config: .init(isEnabled: false, context: .null, url: "test"))
        result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil
            )
        )

        XCTAssert(result)
    }
    
    func testResolverThrowsOnNoUrlProvided() async throws {
        date.offset = 0
        makeResolver(config: defaultAudienceConfig)
        apiClient.onResponse = { _ in
            return AirshipHTTPResponse.make(
                result: AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 1),
                statusCode: 200,
                headers: [:])
        }
        
        var result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil))
        
        XCTAssert(result)
        
        date.offset = 2
        makeResolver(config: .init(isEnabled: true, context: .null, url: nil))
        result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: "https://test.url"))
        
        XCTAssert(result)
        
        date.offset += 2
        do {
            result = try await resolver.resolve(
                deviceInfoProvider: deviceInfoProvider,
                audienceCheckOptions: .init(
                    bypass: false,
                    context: .string("default context"),
                    url: nil))
            XCTFail()
        } catch {
            
        }
    }
    
    func testOverridesBypass() async throws {
        makeResolver(config: defaultAudienceConfig)
        apiClient.onResponse = { _ in
            AirshipHTTPResponse.make(result: nil, statusCode: 400, headers: [:])
        }
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: true,
                context: .null,
                url: nil))
        
        XCTAssert(result)
    }
    
    func testContextDefaultsToConfig() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        apiClient.onResponse = { request in
            XCTAssertEqual(AirshipJSON.string("remote config context"), request.context)
            
            return AirshipHTTPResponse.make(
                result: AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 10),
                statusCode: 200,
                headers: [:])
        }
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: true,
                context: nil,
                url: nil
            )
        )

        XCTAssert(result)
    }
    
    func testReturnsCachedIfAvailable() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        deviceInfoProvider.stableContactInfo = StableContactInfo(contactID: "existing-contact-id", namedUserID: "some user id")
        deviceInfoProvider.channelID = "channel-id"

        apiClient.onResponse = { request in
            return AirshipHTTPResponse.make(
                result: nil,
                statusCode: 400,
                headers: [:])
        }
        
        let cacheKey = "https://test.config:\"default context\":existing-contact-id:channel-id"
        
        await cache.setCachedValue(AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 10), key: cacheKey, ttl: 10)
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil
            )
        )

        XCTAssert(result)
    }
    
    func testIsNotCachedOnError() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        deviceInfoProvider.stableContactInfo = StableContactInfo(contactID: "existing-contact-id", namedUserID: "some user id")
        deviceInfoProvider.channelID = "channel-id"

        apiClient.onResponse = { request in
            return AirshipHTTPResponse.make(
                result: nil,
                statusCode: 400,
                headers: [:])
        }
        
        let cacheKey = "https://test.config:\"default context\":existing-contact-id:channel-id"
        
        var cached: AdditionalAudienceCheckResult? = await cache.getCachedValue(key: cacheKey)
        XCTAssertNil(cached)
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            audienceCheckOptions: .init(
                bypass: false,
                context: .string("default context"),
                url: nil
            )
        )

        XCTAssertFalse(result)
        
        cached = await cache.getCachedValue(key: cacheKey)
        XCTAssertNil(cached)
    }
    
    func testThrowsOnServerError() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        apiClient.onResponse = { request in
            return AirshipHTTPResponse.make(
                result: nil,
                statusCode: 500,
                headers: [:])
        }
        
        do {
            _ = try await resolver.resolve(
                deviceInfoProvider: deviceInfoProvider,
                audienceCheckOptions: .init(
                    bypass: false,
                    context: .string("default context"),
                    url: nil
                )
            )
            XCTFail()
        } catch {}
    }
    
    private func makeResolver(
        config: RemoteConfig.AdditionalAudienceCheckConfig?
    ) {
        resolver = AdditionalAudienceCheckerResolver(
            cache: cache,
            apiClient: apiClient,
            date: date,
            configProvider: { config }
        )
    }
    
}


final class TestAudienceApiClient: AdditionalAudienceCheckerAPIClientProtocol, @unchecked Sendable {

    var onResponse: ((AdditionalAudienceCheckResult.Request) -> AirshipHTTPResponse<AdditionalAudienceCheckResult>)? = nil
    
    func resolve(info: AdditionalAudienceCheckResult.Request) async throws -> AirshipHTTPResponse<AdditionalAudienceCheckResult> {
        guard let handler = onResponse else {
            return AirshipHTTPResponse<AdditionalAudienceCheckResult>.make(result: nil, statusCode: 200, headers: [:])
        }
        
        return handler(info)
    }
}
            
            
