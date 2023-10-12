/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class MeteredUsageApiClientTest: XCTestCase {
    
    private let requestSession = TestAirshipRequestSession()
    private let configDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let notificationCenter = NotificationCenter()
    private var target: MeteredUsageAPIClient!
    
    override func setUp() {
        let config = RuntimeConfig(
            config: AirshipConfig.config(),
            dataStore: configDataStore,
            requestSession: requestSession,
            notificationCenter: notificationCenter)
        
        target = MeteredUsageAPIClient(config: config, session: requestSession)
    }
    
    func testUploadEvents() async throws {
        
        let timestamp = Date()
        
        let events = [
            AirshipMeteredUsageEvent(
                eventID: "event.1",
                entityID: "message.id",
                type: .InAppExperienceImpresssion,
                product: "message",
                reportingContext: try! AirshipJSON.wrap("event.1"),
                timestamp: timestamp
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.2",
                entityID: "landing-page.id",
                type: .InAppExperienceImpresssion,
                product: "landingpage",
                reportingContext: try! AirshipJSON.wrap("event.2"),
                timestamp: timestamp
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.3",
                entityID: "scene.id",
                type: .InAppExperienceImpresssion,
                product: "Scene",
                reportingContext: try! AirshipJSON.wrap("event.3"),
                timestamp: timestamp
            ),
            AirshipMeteredUsageEvent(
                eventID: "event.4",
                entityID: "survey.id",
                type: .InAppExperienceImpresssion,
                product: "Survey",
                reportingContext: try! AirshipJSON.wrap("event.4"),
                timestamp: timestamp
            )
        ]

        requestSession.response = HTTPURLResponse(
            url: URL(string: "test://repose.url")!,
            statusCode: 200,
            httpVersion: "1",
            headerFields: nil)

        var errorOnNoConfig = false
        do {
            let _ = try await target.uploadEvents(events, channelID: "test.channel.id")
        } catch {
            errorOnNoConfig = true
        }

        XCTAssertTrue(errorOnNoConfig)

        let remoteConfig = RemoteConfig(
            remoteDataURL: "test://remoteUrl",
            deviceAPIURL: "test://device",
            analyticsURL: "test://analytics",
            meteredUsageURL: "test://meteredUsage")

        notificationCenter.post(
            name: RemoteConfigManager.remoteConfigUpdatedEvent,
            object: nil,
            userInfo: [RemoteConfigManager.remoteConfigKey: remoteConfig])

        let _ = try await target.uploadEvents(events, channelID: "test.channel.id")

        let request = requestSession.lastRequest
        XCTAssertNotNil(request)
        XCTAssertEqual("test://meteredUsage/metered_usage", request?.url?.absoluteString)
        XCTAssertEqual([
            "Content-Type": "application/json",
            "X-UA-Lib-Version": AirshipVersion.get(),
            "X-UA-Device-Family": "ios",
            "X-UA-Channel-ID": "test.channel.id"
        ], request?.headers)
        XCTAssertEqual("POST", request?.method)

        let body = request?.body
        XCTAssertNotNil(body)

        let decodedBody = try JSONSerialization.jsonObject(with: body!) as! [String : [[String: String]]]

        let timestampString = AirshipUtils.isoDateFormatterUTCWithDelimiter().string(from: timestamp)

        XCTAssertEqual([
            [
                "entity_id": "message.id",
                "event_id": "event.1",
                "product": "message",
                "occurred": timestampString,
                "type": "iax_impression",
                "reporting_context": "event.1"
            ],
            [
                "entity_id": "landing-page.id",
                "event_id": "event.2",
                "product": "landingpage",
                "occurred": timestampString,
                "type": "iax_impression",
                "reporting_context": "event.2"
            ],
            [
                "entity_id": "scene.id",
                "event_id": "event.3",
                "product": "Scene",
                "occurred": timestampString,
                "type": "iax_impression",
                "reporting_context": "event.3"
            ],
            [
                "entity_id": "survey.id",
                "event_id": "event.4",
                "product": "Survey",
                "occurred": timestampString,
                "type": "iax_impression",
                "reporting_context": "event.4"
            ]], decodedBody["usage"])

    }
    
    func testUploadStrippedEvents() async throws {
        
        let timestamp = Date()
        
        let events = [
            AirshipMeteredUsageEvent(
                eventID: "event.1",
                entityID: "message.id",
                type: .InAppExperienceImpresssion,
                product: "message",
                reportingContext: try! AirshipJSON.wrap("event.1"),
                timestamp: timestamp
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.2",
                entityID: "landing-page.id",
                type: .InAppExperienceImpresssion,
                product: "landingpage",
                reportingContext: try! AirshipJSON.wrap("event.2"),
                timestamp: timestamp
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.3",
                entityID: "scene.id",
                type: .InAppExperienceImpresssion,
                product: "Scene",
                reportingContext: try! AirshipJSON.wrap("event.3"),
                timestamp: timestamp
            ).withDisabledAnalytics(),
            AirshipMeteredUsageEvent(
                eventID: "event.4",
                entityID: "survey.id",
                type: .InAppExperienceImpresssion,
                product: "Survey",
                reportingContext: try! AirshipJSON.wrap("event.4"),
                timestamp: timestamp
            ).withDisabledAnalytics()
        ]

        requestSession.response = HTTPURLResponse(
            url: URL(string: "test://repose.url")!,
            statusCode: 200,
            httpVersion: "1",
            headerFields: nil)

        var errorOnNoConfig = false
        do {
            let _ = try await target.uploadEvents(events, channelID: "test.channel.id")
        } catch {
            errorOnNoConfig = true
        }

        XCTAssertTrue(errorOnNoConfig)

        let remoteConfig = RemoteConfig(
            remoteDataURL: "test://remoteUrl",
            deviceAPIURL: "test://device",
            analyticsURL: "test://analytics",
            meteredUsageURL: "test://meteredUsage")

        notificationCenter.post(
            name: RemoteConfigManager.remoteConfigUpdatedEvent,
            object: nil,
            userInfo: [RemoteConfigManager.remoteConfigKey: remoteConfig])

        let _ = try await target.uploadEvents(events, channelID: "test.channel.id")

        let request = requestSession.lastRequest
        XCTAssertNotNil(request)
        XCTAssertEqual("test://meteredUsage/metered_usage", request?.url?.absoluteString)
        XCTAssertEqual([
            "Content-Type": "application/json",
            "X-UA-Lib-Version": AirshipVersion.get(),
            "X-UA-Device-Family": "ios",
            "X-UA-Channel-ID": "test.channel.id"
        ], request?.headers)
        XCTAssertEqual("POST", request?.method)

        let body = request?.body
        XCTAssertNotNil(body)

        let decodedBody = try JSONSerialization.jsonObject(with: body!) as! [String : [[String: String]]]
        
        XCTAssertEqual([
            [
                "event_id": "event.1",
                "product": "message",
                "type": "iax_impression",
            ],
            [
                "event_id": "event.2",
                "product": "landingpage",
                "type": "iax_impression",
            ],
            [
                "event_id": "event.3",
                "product": "Scene",
                "type": "iax_impression",
            ],
            [
                "event_id": "event.4",
                "product": "Survey",
                "type": "iax_impression",
            ]], decodedBody["usage"])
    }
}
