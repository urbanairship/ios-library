import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable
@_spi(AirshipInternal) import AirshipCore

@Suite struct DeferredResolverTest {

    private let resolver: AirshipDeferredResolver
    private let audienceOverridesProvider: DefaultAudienceOverridesProvider = DefaultAudienceOverridesProvider()
    private let client: TestDeferredAPIClient = TestDeferredAPIClient()
    private let exampleURL: URL = URL(string: "exampleurl://")!
    private let altExampleURL: URL = URL(string: "altexampleurl://")!

    init() {
        self.resolver = AirshipDeferredResolver(
            client: client,
            audienceOverrides: audienceOverridesProvider
        )
    }

    @Test
    func testResolve() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            contactID: "some contact ID",
            triggerContext: AirshipTriggerContext(
                type: "some type",
                goal: 10.0,
                event: "event"
            ),
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let tags = [
            TagGroupUpdate(
                group: "some-group",
                tags: ["tag-1", "tag-2"],
                type: .add
            ),
            TagGroupUpdate(
                group: "some-other-group",
                tags: ["tag-3", "tag-4"],
                type: .set
            )
        ]

        let attributes =  [
            AttributeUpdate(
                attribute: "some-attribute",
                type: .set,
                jsonValue: "hello",
                date: Date()
            )
        ]

        /// Local history
        await self.audienceOverridesProvider.channelUpdated(
            channelID: "some channel ID",
            tags: tags,
            attributes: attributes,
            subscriptionLists: nil
        )


        let body = "some body".data(using: .utf8)!
        self.client.onResolve = { url, channel, contact, stateOverrides, audienceOverrides, trigger in
            let expectedStateOverrides = AirshipStateOverrides(
                appVersion: request.appVersion,
                sdkVersion: request.sdkVersion,
                notificationOptIn: request.notificationOptIn,
                localeLangauge: request.locale.getLanguageCode(),
                localeCountry: request.locale.getRegionCode()
            )

            let expectedAudienceOverrides = ChannelAudienceOverrides(
                tags: tags,
                attributes: attributes,
                subscriptionLists: []
            )

            #expect(url == request.url)
            #expect(channel == request.channelID)
            #expect(contact == request.contactID)
            #expect(trigger == request.triggerContext)
            #expect(trigger == request.triggerContext)
            #expect(stateOverrides == expectedStateOverrides)
            #expect(audienceOverrides == expectedAudienceOverrides)
            return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
        }

        let result = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .success(body))
    }

    @Test
    func testResolveNoAudienceOverrides() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)
        self.client.onResolve = { _, _, _, _, audienceOverrides, _ in
            let expectedAudienceOverrides = ChannelAudienceOverrides(
                tags: [],
                attributes: [],
                subscriptionLists: []
            )

            #expect(audienceOverrides == expectedAudienceOverrides)
            return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
        }

        _ = await resolver.resolve(request: request) { data in
            return data
        }
    }

    @Test
    func testResolveParseError() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let statusCode: Int = 200

        let body = "some body".data(using: .utf8)
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: statusCode, headers: [:])
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            throw AirshipErrors.error("parse error")
        }

        #expect(result == .retriableError(statusCode: statusCode))
    }

    @Test
    func testResolveTimedOut() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        self.client.onResolve = { _, _, _, _, _, _ in
            throw AirshipErrors.error("timed out")
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .timedOut)
    }

    @Test
    func testResolve404() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: 404, headers: [:])
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .notFound)
    }

    @Test
    func testResolve409() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: 409, headers: [:])
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .outOfDate)
    }

    @Test
    func testResolveOutOfDateURL() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: 409, headers: [:])
        }

        var result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }
        #expect(result == .outOfDate)

        self.client.onResolve = { _, _, _, _, _, _ in
            Issue.record()
            throw AirshipErrors.error("Failed")
        }

        result = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .outOfDate)
    }

    @Test
    func testResolve429() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let statusCode: Int = 429
        let body = "some body".data(using: .utf8)!
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: statusCode, headers: ["Location": self.altExampleURL.absoluteString])
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .retriableError(statusCode: statusCode))

        self.client.onResolve = { url, _, _, _, _, _ in
            #expect(url == self.altExampleURL)
            return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
        }

        let anotherResult: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(anotherResult == .success(body))

    }

    @Test
    func testResolve429RetryAfter() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let statusCode: Int = 429
        let body = "some body".data(using: .utf8)!
        self.client.onResolve = { _, _, _, _, _, _ in
            return AirshipHTTPResponse(result: body, statusCode: statusCode, headers: ["Retry-After": "100.0"])
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .retriableError(retryAfter: 100.0,  statusCode: statusCode))
    }

    @Test
    func testResolve307() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)!
        self.client.onResolve = { url, _, _, _, _, _ in
            if (url == self.exampleURL) {
                return AirshipHTTPResponse(result: nil, statusCode: 307, headers: ["Location": self.altExampleURL.absoluteString])
            } else {
                return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
            }
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .success(body))
    }
    
    @Test
    func testRedirectTwice() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)!
        self.client.onResolve = { url, _, _, _, _, _ in
            if (url == self.exampleURL) {
                return AirshipHTTPResponse(result: nil, statusCode: 307, headers: ["Location": "altexampleurl://1"])
            } else {
                return AirshipHTTPResponse(result: body, statusCode: 307, headers:  ["Location": "altexampleurl://2"])
            }
        }

        var result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }
        
        #expect(result == .retriableError(retryAfter: nil, statusCode: 307))

        self.client.onResolve = { url, _, _, _, _, _ in
            #expect(url.absoluteString == "altexampleurl://2")
            return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
        }
        
        result = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .success(body))
    }

    @Test
    func testResolve307RetryAfter() async throws {
        let request = DeferredRequest(
            url: exampleURL,
            channelID: "some channel ID",
            locale: Locale(identifier: "de-DE"),
            notificationOptIn: true
        )

        let body = "some body".data(using: .utf8)!

        let statusCode: Int = 307
        self.client.onResolve = { url, _, _, _, _, _ in
            if (url == self.exampleURL) {
                return AirshipHTTPResponse(
                    result: nil,
                    statusCode: statusCode,
                    headers: [
                        "Location": self.altExampleURL.absoluteString,
                        "Retry-After": "20.0"
                    ]
                )
            } else {
                return AirshipHTTPResponse(result: body, statusCode: 200, headers: [:])
            }
        }

        let result: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(result == .retriableError(retryAfter: 20.0, statusCode: statusCode))

        let anotherResult: AirshipDeferredResult<Data> = await resolver.resolve(request: request) { data in
            return data
        }

        #expect(anotherResult == .success(body))
    }
}


fileprivate class TestDeferredAPIClient: DeferredAPIClientProtocol, @unchecked Sendable {
    var onResolve: ((URL, String, String?, AirshipStateOverrides, ChannelAudienceOverrides, AirshipTriggerContext?) throws -> AirshipHTTPResponse<Data>)?

    func resolve(
        url: URL,
        channelID: String,
        contactID: String?,
        stateOverrides: AirshipStateOverrides,
        audienceOverrides: ChannelAudienceOverrides,
        triggerContext: AirshipTriggerContext?
    ) async throws -> AirshipHTTPResponse<Data> {
        try onResolve!(url, channelID, contactID, stateOverrides, audienceOverrides, triggerContext)
    }
}
