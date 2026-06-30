/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable
import AirshipFeatureFlags

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

struct FeatureFlagDeferredResolverTest {

    private let cache: TestCache = TestCache()
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let sleeper: TestTaskSleeper = TestTaskSleeper()

    private let resolver: FeatureFlagDeferredResolver

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
        reportingMetadata: "reporting",
        flagPayload: .deferredPayload(
            .init(
                deferred: .init(url: URL(string: "example://example")!)
            )
        )
    )

    init() {
        resolver = FeatureFlagDeferredResolver(
            cache: cache,
            deferredResolver: deferredResolver,
            date: date,
            taskSleeper: sleeper
        )
    }

    @Test
    func testResolve() async throws {
        try await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { request in
                confirmation()
                #expect(request == self.request)
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

            #expect(expected == result)
        }
    }

    @Test
    func testResolveVariables() async throws {
        try await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { request in
                confirmation()
                #expect(request == self.request)
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

            #expect(expected == result)
        }
    }

    @Test
    func testResolveNotFound() async throws {
        try await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .notFound
            }

            let result = try await self.resolver.resolve(
                request: request,
                flagInfo: flagInfo
            )

            #expect(DeferredFlagResponse.notFound == result)
        }
    }

    @Test
    func testResolveOutOfDate() async throws {
        await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .outOfDate
            }

            do {
                _ = try await self.resolver.resolve(
                    request: request,
                    flagInfo: flagInfo
                )
                Issue.record("Should throw")
            } catch {
                #expect(error as! FeatureFlagEvaluationError == .outOfDate)
            }
        }
    }

    @Test
    func testResolveTimedOut() async throws {
        await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .timedOut
            }

            do {
                _ = try await self.resolver.resolve(
                    request: request,
                    flagInfo: flagInfo
                )
                Issue.record("Should throw")
            } catch {
                #expect(error as! FeatureFlagEvaluationError == .connectionError(errorMessage: "Failed to resolve flag."))
            }
        }
    }

    @Test
    func testResolveConnectionErrorNoRetryAfter() async throws {
        await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .retriableError(statusCode: nil)
            }

            do {
                _ = try await self.resolver.resolve(
                    request: request,
                    flagInfo: flagInfo
                )
                Issue.record("Should throw")
            } catch {
                #expect(error as! FeatureFlagEvaluationError == .connectionError(errorMessage: "Failed to resolve flag."))
            }
        }

        #expect(sleeper.sleeps.isEmpty)
    }

    @Test
    func testResolveConnectionErrorShortRetryAfter() async throws {
        await confirmation("flag resolved", expectedCount: 2) { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .retriableError(retryAfter: 5)
            }

            do {
                _ = try await self.resolver.resolve(
                    request: request,
                    flagInfo: flagInfo
                )
                Issue.record("Should throw")
            } catch {
                #expect(error as! FeatureFlagEvaluationError == .connectionError(errorMessage: "Failed to resolve flag."))
            }
        }

        #expect(sleeper.sleeps == [5])
    }

    @Test
    func testResolveConnectionErrorLongRetryAfter() async throws {
        await confirmation("flag resolved") { confirmation in
            self.deferredResolver.onData = { _ in
                confirmation()
                return .retriableError(retryAfter: 6)
            }

            do {
                _ = try await self.resolver.resolve(
                    request: request,
                    flagInfo: flagInfo
                )
                Issue.record("Should throw")
            } catch {
                #expect(error as! FeatureFlagEvaluationError == .connectionError(errorMessage: "Failed to resolve flag."))
            }
        }

        #expect(sleeper.sleeps == [])

        self.date.offset += 1

        self.deferredResolver.onData = { _ in
            #expect(self.sleeper.sleeps == [5])
            return .notFound
        }

        let result = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )

        #expect(DeferredFlagResponse.notFound == result)
    }

    @Test
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

        #expect(
            try JSONDecoder().decode(DeferredFlagResponse.self, from: entry.data) == expectedValue
        )

        #expect(entry.ttl == 60.0)

        self.deferredResolver.onData = { _ in
            return .notFound
        }

        let cached = try await self.resolver.resolve(
            request: request,
            flagInfo: flagInfo
        )
        #expect(cached == flag)
    }

    @Test
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
            reportingMetadata: "reporting",
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
        #expect(
            try JSONDecoder().decode(DeferredFlagResponse.self, from: entry.data) == result
        )

        #expect(entry.ttl == 120.0)
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
        case .retriableError(retryAfter: let retryAfter, statusCode: let statusCode): return .retriableError(retryAfter: retryAfter, statusCode: statusCode)
        @unknown default:
            fatalError()
        }
    }
}



fileprivate final class TestTaskSleeper : AirshipTaskSleeper, @unchecked Sendable {
    var sleeps : [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
    }
}
