/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct AdditionalAudienceCheckerResolverTest {
    
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let date = UATestDate(dateOverride: Date())
    private let apiClient = TestAudienceApiClient()
    private let cache: AirshipCache
    
    private var resolver: AdditionalAudienceCheckerResolver!
    private let deviceInfoProvider: TestDeviceInfoProvider = TestDeviceInfoProvider()

    private let defaultAudienceConfig = RemoteConfig.AdditionalAudienceCheckConfig(
        isEnabled: true,
        context: "remote config context",
        url: "https://test.config")
    
    init() async throws {
        cache = TestAirshipCoreDataCache.makeCache(date: date)
    }
    
    @Test
    mutating func testHappyPath() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        deviceInfoProvider.stableContactInfo = StableContactInfo(contactID: "existing-contact-id", namedUserID: "some user id")
        deviceInfoProvider.channelID = "channel-id"

        apiClient.onResponse = { request in
            #expect("channel-id" == request.channelID)
            #expect("existing-contact-id" == request.contactID)
            #expect("some user id" == request.namedUserID)
            #expect(AirshipJSON.string("default context") == request.context)
            #expect("https://test.config" == request.url.absoluteString)
            
            return AirshipHTTPResponse.make(
                result: AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 10),
                statusCode: 200,
                headers: [:])
        }
        
        let cacheKey = "https://test.config:\"default context\":existing-contact-id:channel-id"
        
        var cached: AdditionalAudienceCheckResult? = await cache.getCachedValue(key: cacheKey)
        #expect(cached == nil)
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil
            )
        )

        cached = await cache.getCachedValue(key: cacheKey)
        #expect(true == cached?.isMatched)
        #expect(10 == cached?.cacheTTL)
        #expect(result)
    }
    
    @Test
    mutating func testResolverReturnsTrueOnNoConfigOrDisabled() async throws {
        makeResolver(config: nil)
        
        var result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil
            )
        )

        #expect(result)
        
        makeResolver(config: .init(isEnabled: false, context: .null, url: "test"))
        result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil
            )
        )

        #expect(result)
    }
    
    @Test
    mutating func testResolverThrowsOnNoUrlProvided() async throws {
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
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil))
        
        #expect(result)
        
        date.offset = 2
        makeResolver(config: .init(isEnabled: true, context: .null, url: nil))
        result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: "https://test.url"))
        
        #expect(result)
        
        date.offset += 2
        do {
            result = try await resolver.resolve(
                deviceInfoProvider: deviceInfoProvider,
                additionalAudienceCheckOverrides: .init(
                    bypass: false,
                    context: "default context",
                    url: nil))
            Issue.record()
        } catch {
            
        }
    }
    
    @Test
    mutating func testOverridesBypass() async throws {
        makeResolver(config: defaultAudienceConfig)
        apiClient.onResponse = { _ in
            AirshipHTTPResponse.make(result: nil, statusCode: 400, headers: [:])
        }
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: true,
                context: .null,
                url: nil))
        
        #expect(result)
    }
    
    @Test
    mutating func testContextDefaultsToConfig() async throws {
        makeResolver(config: defaultAudienceConfig)
        
        apiClient.onResponse = { request in
            #expect(AirshipJSON.string("remote config context") == request.context)
            
            return AirshipHTTPResponse.make(
                result: AdditionalAudienceCheckResult(isMatched: true, cacheTTL: 10),
                statusCode: 200,
                headers: [:])
        }
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: true,
                context: nil,
                url: nil
            )
        )

        #expect(result)
    }
    
    @Test
    mutating func testReturnsCachedIfAvailable() async throws {
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
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil
            )
        )

        #expect(result)
    }
    
    @Test
    mutating func testIsNotCachedOnError() async throws {
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
        #expect(cached == nil)
        
        let result = try await resolver.resolve(
            deviceInfoProvider: deviceInfoProvider,
            additionalAudienceCheckOverrides: .init(
                bypass: false,
                context: "default context",
                url: nil
            )
        )

        #expect(!(result))
        
        cached = await cache.getCachedValue(key: cacheKey)
        #expect(cached == nil)
    }
    
    @Test
    mutating func testThrowsOnServerError() async throws {
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
                additionalAudienceCheckOverrides: .init(
                    bypass: false,
                    context: "default context",
                    url: nil
                )
            )
            Issue.record()
        } catch {}
    }
    
    private mutating func makeResolver(
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
            
            
