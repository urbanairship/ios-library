/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipFeatureFlags

import AirshipCore

final class FeatureFlagDeferredResolverTest: XCTestCase {

    private let cache: TestCache = TestCache()
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let sleeper: TestTaskSleeper = TestTaskSleeper()

    private var resolver: FeatureFlagDeferredResolver!

    private let request = DeferredRequest(
        url: URL(string: "example://example")!,
        channelID: "some channel id",
        contactID: "some contact id",
        locale: Locale.current,
        notificationOptIn: true
    )

    private let flagInfo = FeatureFlagInfo(
        id: "some-id",
        created: Date(),
        lastUpdated: Date(),
        name: "flag name",
        reportingMetadata: .string("reporting"),
        flagPayload: .deferredPayload(
            .init(
                deferred: .init(url: URL(string: "example://example")!)
            )
        )
    )

    override func setUpWithError() throws {
        resolver = FeatureFlagDeferredResolver(
            cache: cache,
            deferredResolver: deferredResolver,
            date: date,
            taskSleeper: sleeper
        )
    }

    func testResolve() async throws {
        let expectation = expectation(description: "flag resolved")

        self.deferredResolver.onData = { request in
            expectation.fulfill()
            XCTAssertEqual(request, self.request)
            let data = try! AirshipJSON.wrap([
                "is_eligible": false,
                "reporting_metadata": ["reporting": "reporting"]
            ]).toData()
            return .success(data)
        }

        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        let expected = DeferredFlagResponse.found(
            DeferredFlag(
                isEligible: false,
                variables: nil,
                reportingMetadata: try! AirshipJSON.wrap(["reporting": "reporting"])
            )
        )


        XCTAssertEqual(expected, result)

        await fulfillment(of: [expectation])
    }

    func testResolveVariables() async throws {
        let expectation = expectation(description: "flag resolved")

        self.deferredResolver.onData = { request in
            expectation.fulfill()
            XCTAssertEqual(request, self.request)
            let data = try! AirshipJSON.wrap([
                "is_eligible": true,
                "variables": [
                    "type": "fixed",
                    "data": [
                        "var": "one"
                    ]
                ],
                "reporting_metadata": ["reporting": "reporting"]
            ]).toData()
            return .success(data)
        }

        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        let expected = DeferredFlagResponse.found(
            DeferredFlag(
                isEligible: true,
                variables: .fixed(try! AirshipJSON.wrap(["var": "one"])),
                reportingMetadata: try! AirshipJSON.wrap(["reporting": "reporting"])
            )
        )

        XCTAssertEqual(expected, result)

        await fulfillment(of: [expectation])
    }

    func testResolveNotFound() async throws {
        let expectation = expectation(description: "flag resolved")
        self.deferredResolver.onData = { _ in
            expectation.fulfill()
            return .notFound
        }


        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        XCTAssertEqual(DeferredFlagResponse.notFound, result)

        await fulfillment(of: [expectation])

    }

    func testResolveOutOfDate() async throws {
        let expectation = expectation(description: "flag resolved")
        self.deferredResolver.onData = { _ in
            expectation.fulfill()
            return .outOfDate
        }

        do {
            _ = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )
            XCTFail()
        } catch {
            XCTAssertEqual(FeatureFlagEvaluationError.outOfDate, error as! FeatureFlagEvaluationError)
        }

        await fulfillment(of: [expectation])
    }

    func testResolveTimedOut() async throws {
        let expectation = expectation(description: "flag resolved")
        self.deferredResolver.onData = { _ in
            expectation.fulfill()
            return .timedOut
        }

        do {
            _ = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )
            XCTFail()
        } catch {
            XCTAssertEqual(FeatureFlagEvaluationError.connectionError, error as! FeatureFlagEvaluationError)
        }

        await fulfillment(of: [expectation])
    }

    func testResolveConnectionErrorNoRetryAfter() async throws {
        let expectation = expectation(description: "flag resolved")
        self.deferredResolver.onData = { _ in
            expectation.fulfill()
            return .retriableError()
        }

        do {
            _ = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )
            XCTFail()
        } catch {
            XCTAssertEqual(FeatureFlagEvaluationError.connectionError, error as! FeatureFlagEvaluationError)
        }

        await fulfillment(of: [expectation])

        XCTAssertTrue(sleeper.sleeps.isEmpty)
    }

    func testResolveConnectionErrorShortRetryAfter() async throws {
        let expectation = expectation(description: "flag resolved")
        expectation.expectedFulfillmentCount = 2
        self.deferredResolver.onData = { _ in
            expectation.fulfill()
            return .retriableError(retryAfter: 5)
        }

        do {
            _ = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )
            XCTFail()
        } catch {
            XCTAssertEqual(FeatureFlagEvaluationError.connectionError, error as! FeatureFlagEvaluationError)
        }

        await fulfillment(of: [expectation])

        XCTAssertEqual(sleeper.sleeps, [5])
    }

    func testResolveConnectionErrorLongRetryAfter() async throws {
        let expecation = expectation(description: "flag resolved")
        self.deferredResolver.onData = { _ in
            expecation.fulfill()
            return .retriableError(retryAfter: 6)
        }

        do {
            _ = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )
            XCTFail()
        } catch {
            XCTAssertEqual(FeatureFlagEvaluationError.connectionError, error as! FeatureFlagEvaluationError)
        }

        await fulfillment(of: [expecation])
        XCTAssertEqual(sleeper.sleeps, [])

        self.date.offset += 1

        self.deferredResolver.onData = { _ in
            XCTAssertEqual(self.sleeper.sleeps, [5])
            return .notFound
        }

        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        XCTAssertEqual(DeferredFlagResponse.notFound, result)
    }

    func testCache() async throws {
        self.deferredResolver.onData = { _ in
            let data = try! AirshipJSON.wrap([
                "is_eligible": true,
                "reporting_metadata": ["reporting": "reporting"]
            ]).toData()
            return .success(data)
        }

        let flag = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        let expectedKey = [
            flagInfo.name,
            flagInfo.id,
            "\(flagInfo.lastUpdated.timeIntervalSince1970)",
            request.contactID ?? "",
            request.url.absoluteString,
        ].joined(separator: ":")

        let entry = await self.cache.entry(key: expectedKey)!


        let expectedValue = DeferredFlagResponse.found(
            DeferredFlag(
                isEligible: true,
                variables: nil,
                reportingMetadata: try! AirshipJSON.wrap(["reporting": "reporting"])
            )
        )

        XCTAssertEqual(
            try JSONDecoder().decode(DeferredFlagResponse.self, from: entry.data),
            expectedValue
        )

        XCTAssertEqual(entry.ttl, 60.0)

        self.deferredResolver.onData = { _ in
            return .notFound
        }

        let cached = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )
        XCTAssertEqual(cached, flag)
    }

    func testCacheTTL() async throws {
        self.deferredResolver.onData = { _ in
            let data = try! AirshipJSON.wrap([
                "is_eligible": true,
                "reporting_metadata": ["reporting": "reporting"]
            ]).toData()
            return .success(data)
        }

        let flagInfo = FeatureFlagInfo(
            id: "some-id",
            created: Date(),
            lastUpdated: Date(),
            name: "flag name",
            reportingMetadata: .string("reporting"),
            flagPayload: .deferredPayload(
                .init(
                    deferred: .init(url: URL(string: "example://example")!)
                )
            ),
            evaluationOptions: EvaluationOptions(ttlMS: 120000)
        )

        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        let expectedKey = [
            flagInfo.name,
            flagInfo.id,
            "\(flagInfo.lastUpdated.timeIntervalSince1970)",
            request.contactID ?? "",
            request.url.absoluteString,
        ].joined(separator: ":")

        let entry = await self.cache.entry(key: expectedKey)!
        XCTAssertEqual(
            try JSONDecoder().decode(DeferredFlagResponse.self, from: entry.data),
            result
        )

        XCTAssertEqual(entry.ttl, 120.0)
    }


}


fileprivate final class TestDeferredResolver: AirshipDeferredResolverProtocol, @unchecked Sendable {
    var onData: ((DeferredRequest) async -> AirshipDeferredResult<Data>)?

    func resolve<T>(
        request: DeferredRequest,
        resultParser: @escaping @Sendable (Data) async throws -> T
    ) async -> AirshipDeferredResult<T> where T : Sendable {
        switch(await onData?(request) ?? .timedOut) {
        case .success(let data):
            do {
                let value = try await resultParser(data)
                return .success(value)
            } catch {
                return .retriableError()
            }
        case .timedOut: return .timedOut
        case .outOfDate: return .outOfDate
        case .notFound: return .notFound
        case .retriableError(retryAfter: let retryAfter): return .retriableError(retryAfter: retryAfter)
        @unknown default:
            fatalError()
        }
    }
}


fileprivate struct CacheEntry: Sendable {
    let data: Data
    let ttl: TimeInterval
}

fileprivate actor TestCache: AirshipCache {
    private var values: [String: CacheEntry] = [:]

    func entry(key: String) async -> CacheEntry? {
        return self.values[key]
    }

    func getCachedValue<T>(key: String) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        return await getCachedValue(key: key, decoder: AirshipJSON.defaultDecoder)
    }
    
    func getCachedValue<T>(key: String, decoder: JSONDecoder) async -> T? where T : Decodable, T : Encodable, T : Sendable {
        guard let value = self.values[key] else {
            return nil
        }

        return try? decoder.decode(T.self, from: value.data)
    }
    
    func setCachedValue<T>(_ value: T?, key: String, ttl: TimeInterval) async where T : Decodable, T : Encodable, T : Sendable {
        return await setCachedValue(value, key: key, ttl: ttl, encoder: AirshipJSON.defaultEncoder)
    }
    
    func setCachedValue<T>(
        _ value: T?,
        key: String,
        ttl: TimeInterval,
        encoder: JSONEncoder
    ) async where T : Decodable, T : Encodable, T : Sendable {
        guard let value = value, let data = try? encoder.encode(value) else {
            return
        }

        self.values[key] = CacheEntry(data: data, ttl: ttl)
    }

}

fileprivate final class TestTaskSleeper : AirshipTaskSleeper, @unchecked Sendable {
    var sleeps : [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
    }
}
