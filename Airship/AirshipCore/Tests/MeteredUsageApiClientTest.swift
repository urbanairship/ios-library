/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
@Suite struct MeteredUsageApiClientTest {

    private let requestSession = TestAirshipRequestSession()
    private let configDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let target: MeteredUsageAPIClient
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    init() async throws {
        self.config.updateRemoteConfig(
            RemoteConfig(
                airshipConfig: RemoteConfig.AirshipConfig(
                    remoteDataURL: "test://remoteUrl",
                    deviceAPIURL: "test://device",
                    analyticsURL: "test://analytics",
                    meteredUsageURL: "test://meteredUsage"
                )
            )
        )

        target = MeteredUsageAPIClient(config: config, session: requestSession)
    }

    @Test
    func testUploadEventsNoConfig() async throws {
        self.config.updateRemoteConfig(RemoteConfig())
        let timestamp = Date()

        let events = [
            AirshipMeteredUsageEvent(
                eventID: "event.1",
                entityID: "message.id",
                usageType: .inAppExperienceImpression,
                product: "message",
                reportingContext: try! AirshipJSON.wrap("event.1"),
                timestamp: timestamp,
                contactID: "contact-id-1"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.2",
                entityID: "landing-page.id",
                usageType: .inAppExperienceImpression,
                product: "landingpage",
                reportingContext: try! AirshipJSON.wrap("event.2"),
                timestamp: timestamp,
                contactID: "contact-id-2"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.3",
                entityID: "scene.id",
                usageType: .inAppExperienceImpression,
                product: "Scene",
                reportingContext: try! AirshipJSON.wrap("event.3"),
                timestamp: timestamp,
                contactID: "contact-id-3"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.4",
                entityID: "survey.id",
                usageType: .inAppExperienceImpression,
                product: "Survey",
                reportingContext: try! AirshipJSON.wrap("event.4"),
                timestamp: timestamp,
                contactID: "contact-id-4"
            )
        ]

        requestSession.response = HTTPURLResponse(
            url: URL(string: "test://repose.url")!,
            statusCode: 200,
            httpVersion: "1",
            headerFields: nil)

        self.config.updateRemoteConfig(RemoteConfig())
        do {
            let _ = try await target.uploadEvents(events, channelID: "test.channel.id")
            Issue.record("Should throw")
        } catch {
        }
    }

    @Test
    func testUploadEvents() async throws {
        let timestamp = Date()

        let events = [
            AirshipMeteredUsageEvent(
                eventID: "event.1",
                entityID: "message.id",
                usageType: .inAppExperienceImpression,
                product: "message",
                reportingContext: try! AirshipJSON.wrap("event.1"),
                timestamp: timestamp,
                contactID: "contact-id-1"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.2",
                entityID: "landing-page.id",
                usageType: .inAppExperienceImpression,
                product: "landingpage",
                reportingContext: try! AirshipJSON.wrap("event.2"),
                timestamp: timestamp,
                contactID: "contact-id-2"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.3",
                entityID: "scene.id",
                usageType: .inAppExperienceImpression,
                product: "Scene",
                reportingContext: try! AirshipJSON.wrap("event.3"),
                timestamp: timestamp,
                contactID: "contact-id-3"
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.4",
                entityID: "survey.id",
                usageType: .inAppExperienceImpression,
                product: "Survey",
                reportingContext: try! AirshipJSON.wrap("event.4"),
                timestamp: timestamp,
                contactID: "contact-id-4"
            )
        ]

        requestSession.response = HTTPURLResponse(
            url: URL(string: "test://repose.url")!,
            statusCode: 200,
            httpVersion: "1",
            headerFields: nil)

        let _ = try await target.uploadEvents(events, channelID: "test.channel.id")

        let request = requestSession.lastRequest
        #expect(request != nil)
        #expect("test://meteredUsage/api/metered-usage" == request?.url?.absoluteString)
        #expect([
            "Content-Type": "application/json",
            "X-UA-Lib-Version": AirshipVersion.version,
            "X-UA-Device-Family": "ios",
            "X-UA-Channel-ID": "test.channel.id",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ] == request?.headers)
        #expect("POST" == request?.method)

        let body = request?.body
        #expect(body != nil)

        let decodedBody = try JSONSerialization.jsonObject(with: body!) as! [String : [[String: String]]]

        let timestampString = AirshipDateFormatter.string(fromDate: timestamp, format: .iso8601)

        #expect([
            [
                "entity_id": "message.id",
                "event_id": "event.1",
                "product": "message",
                "occurred": timestampString,
                "usage_type": "iax_impression",
                "reporting_context": "event.1",
                "contact_id": "contact-id-1"
            ],
            [
                "entity_id": "landing-page.id",
                "event_id": "event.2",
                "product": "landingpage",
                "occurred": timestampString,
                "usage_type": "iax_impression",
                "reporting_context": "event.2",
                "contact_id": "contact-id-2"
            ],
            [
                "entity_id": "scene.id",
                "event_id": "event.3",
                "product": "Scene",
                "occurred": timestampString,
                "usage_type": "iax_impression",
                "reporting_context": "event.3",
                "contact_id": "contact-id-3"
            ],
            [
                "entity_id": "survey.id",
                "event_id": "event.4",
                "product": "Survey",
                "occurred": timestampString,
                "usage_type": "iax_impression",
                "reporting_context": "event.4",
                "contact_id": "contact-id-4"
            ]] == decodedBody["usage"])

    }
    
    @Test
    func testUploadStrippedEvents() async throws {
        let timestamp = Date()
        
        let events = [
            AirshipMeteredUsageEvent(
                eventID: "event.1",
                entityID: "message.id",
                usageType: .inAppExperienceImpression,
                product: "message",
                reportingContext: try! AirshipJSON.wrap("event.1"),
                timestamp: timestamp,
                contactID: "contact-id-1"
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.2",
                entityID: "landing-page.id",
                usageType: .inAppExperienceImpression,
                product: "landingpage",
                reportingContext: try! AirshipJSON.wrap("event.2"),
                timestamp: timestamp,
                contactID: "contact-id-2"
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.3",
                entityID: "scene.id",
                usageType: .inAppExperienceImpression,
                product: "Scene",
                reportingContext: try! AirshipJSON.wrap("event.3"),
                timestamp: timestamp,
                contactID: "contact-id-3"
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.4",
                entityID: "survey.id",
                usageType: .inAppExperienceImpression,
                product: "Survey",
                reportingContext: try! AirshipJSON.wrap("event.4"),
                timestamp: timestamp,
                contactID: "contact-id-4"
            ).withDisabledAnalytics()
        ]

        requestSession.response = HTTPURLResponse(
            url: URL(string: "test://repose.url")!,
            statusCode: 200,
            httpVersion: "1",
            headerFields: nil)

        let _ = try await target.uploadEvents(events, channelID: "test.channel.id")

        let request = requestSession.lastRequest
        #expect(request != nil)
        #expect("test://meteredUsage/api/metered-usage" == request?.url?.absoluteString)
        #expect([
            "Content-Type": "application/json",
            "X-UA-Lib-Version": AirshipVersion.version,
            "X-UA-Device-Family": "ios",
            "X-UA-Channel-ID": "test.channel.id",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ] == request?.headers)
        #expect("POST" == request?.method)

        let body = request?.body
        #expect(body != nil)

        let decodedBody = try JSONSerialization.jsonObject(with: body!) as! [String : [[String: String]]]
        
        #expect([
            [
                "event_id": "event.1",
                "product": "message",
                "usage_type": "iax_impression",
            ],
            [
                "event_id": "event.2",
                "product": "landingpage",
                "usage_type": "iax_impression",
            ],
            [
                "event_id": "event.3",
                "product": "Scene",
                "usage_type": "iax_impression",
            ],
            [
                "event_id": "event.4",
                "product": "Survey",
                "usage_type": "iax_impression",
            ]] == decodedBody["usage"])
    }
}
