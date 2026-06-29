/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable import AirshipScenes

@Suite(.timeLimit(.minutes(1)))
struct ThomasLayoutEventRecorderTest {

    private let airshipAnalytics = TestAnalytics()
    private let meteredUsage = TestMeteredUsage()
    private let eventRecorder: ThomasLayoutEventRecorder

    private let campaigns = try! AirshipJSON.wrap(
        ["campaign1": "data1", "campaign2": "data2"]
    )
    private let experimentResult = ExperimentResult(
        channelID: "some channel",
        contactID: "some contact",
        isMatch: true,
        reportingMetadata: [AirshipJSON.string("some reporting")]
    )
    private let scheduleID = "5362C754-17A9-48B8-B101-60D9DC5688A2"
    private let reportingMetadata = AirshipJSON.string("reporting info")
    private let renderedLocale = try! AirshipJSON.wrap(["en-US"])

    init() {
        self.eventRecorder = ThomasLayoutEventRecorder(
            airshipAnalytics: airshipAnalytics,
            meteredUsage: meteredUsage
        )
    }

    @Test
    func eventData() async throws {
        let layoutEvent = TestThomasLayoutEvent(
            name: .appInit,
            data: TestData(field: "something", anotherField: "something something")
        )

        let data = ThomasLayoutEventData(
            event: layoutEvent,
            context: ThomasLayoutEventContext(
                reportingContext: reportingMetadata,
                experimentsReportingData: experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: scheduleID, campaigns: campaigns),
            renderedLocale: renderedLocale
        )

        eventRecorder.recordEvent(thomasLayoutEventData: data)

        let expectedJSON = """
        {
           "context":{
              "reporting_context":"reporting info",
              "experiments":[
                 "some reporting"
              ]
           },
           "source":"urban-airship",
           "rendered_locale":[
              "en-US"
           ],
           "id":{
              "campaigns":{
                 "campaign1":"data1",
                 "campaign2":"data2"
              },
              "message_id":"5362C754-17A9-48B8-B101-60D9DC5688A2"
           },
           "field":"something",
           "anotherField":"something something"
        }
        """

        let event = airshipAnalytics.events.first!

        #expect(event.eventType == layoutEvent.name)
        let expectedEventData = try AirshipJSON.from(json: expectedJSON)
        #expect(event.eventData == expectedEventData)
    }

    @Test
    func conversionIDs() async throws {
        let layoutEvent = TestThomasLayoutEvent(
            name: .featureFlagInteraction,
            data: TestData(field: "something", anotherField: "something something")
        )

        airshipAnalytics.conversionSendID = UUID().uuidString
        airshipAnalytics.conversionPushMetadata = UUID().uuidString

        let data = ThomasLayoutEventData(
            event: layoutEvent,
            context: ThomasLayoutEventContext(
                reportingContext: reportingMetadata,
                experimentsReportingData: experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: scheduleID, campaigns: campaigns),
            renderedLocale: renderedLocale
        )

        eventRecorder.recordEvent(thomasLayoutEventData: data)

        let expectedJSON = """
        {
           "context":{
              "reporting_context":"reporting info",
              "experiments":[
                 "some reporting"
              ]
           },
           "source":"urban-airship",
           "rendered_locale":[
              "en-US"
           ],
           "id":{
              "campaigns":{
                 "campaign1":"data1",
                 "campaign2":"data2"
              },
              "message_id":"5362C754-17A9-48B8-B101-60D9DC5688A2"
           },
           "field":"something",
           "anotherField":"something something",
           "conversion_send_id": "\(airshipAnalytics.conversionSendID!)",
           "conversion_metadata": "\(airshipAnalytics.conversionPushMetadata!)"
        }
        """

        let event = airshipAnalytics.events.first!

        #expect(event.eventType == layoutEvent.name)
        let expectedEventData = try AirshipJSON.from(json: expectedJSON)
        #expect(event.eventData == expectedEventData)
    }

    @Test
    func eventDataError() async throws {
        let layoutEvent = TestThomasLayoutEvent(
            name: .appForeground,
            data: ErrorData(field: "something", anotherField: "something something")
        )

        let data = ThomasLayoutEventData(
            event: layoutEvent,
            context: ThomasLayoutEventContext(
                reportingContext: reportingMetadata,
                experimentsReportingData: experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: scheduleID, campaigns: campaigns),
            renderedLocale: renderedLocale
        )

        eventRecorder.recordEvent(thomasLayoutEventData: data)

        #expect(airshipAnalytics.events.isEmpty)
    }
}

fileprivate struct TestData: Encodable, Sendable {
    var field: String
    var anotherField: String
}

fileprivate struct ErrorData: Encodable, Sendable {
    var field: String
    var anotherField: String

    enum CodingKeys: CodingKey {
        case field
        case anotherField
    }

    func encode(to encoder: any Encoder) throws {
        throw AirshipErrors.error("Failed")
    }
}

actor TestMeteredUsage: AirshipMeteredUsage {
    var events: [AirshipMeteredUsageEvent] = []
    func addEvent(_ event: AirshipCore.AirshipMeteredUsageEvent) async throws {
        events.append(event)
    }
}
