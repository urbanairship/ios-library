/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

class InAppEventRecorderTest: XCTestCase {

    private let analytics: TestAnalytics = TestAnalytics()
    private var eventRecorder: InAppEventRecorder!

    private let campaigns =  try! AirshipJSON.wrap(
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

    override func setUp() async throws {
        self.eventRecorder = InAppEventRecorder(analytics: analytics)
    }

    func testEventData() async throws {
        let inAppEvent = TestInAppEvent(
            name: "some-name",
            data: TestData(field: "something", anotherField: "something something")
        )

        let data = InAppEventData(
            event: inAppEvent,
            context: InAppEventContext(
                reportingContext: self.reportingMetadata,
                experimentsReportingData: self.experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: self.scheduleID, campaigns: self.campaigns),
            renderedLocale: self.renderedLocale
        )


        self.eventRecorder.recordEvent(inAppEventData: data)

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

        let event = self.analytics.events.first!

        XCTAssertEqual(event.eventType, inAppEvent.name)
        XCTAssertEqual(try AirshipJSON.wrap(event.data), try AirshipJSON.from(json: expectedJSON))
    }

    func testConversionIDs() async throws {
        let inAppEvent = TestInAppEvent(
            name: "some-name",
            data: TestData(field: "something", anotherField: "something something")
        )

        self.analytics.conversionSendID = UUID().uuidString
        self.analytics.conversionPushMetadata = UUID().uuidString

        let data = InAppEventData(
            event: inAppEvent,
            context: InAppEventContext(
                reportingContext: self.reportingMetadata,
                experimentsReportingData: self.experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: self.scheduleID, campaigns: self.campaigns),
            renderedLocale: self.renderedLocale
        )


        self.eventRecorder.recordEvent(inAppEventData: data)


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
           "conversion_send_id": "\(self.analytics.conversionSendID!)",
           "conversion_metadata": "\(self.analytics.conversionPushMetadata!)"
        }
        """

        let event = self.analytics.events.first!

        XCTAssertEqual(event.eventType, inAppEvent.name)
        XCTAssertEqual(try AirshipJSON.wrap(event.data), try AirshipJSON.from(json: expectedJSON))
    }

    func testEventDataError() async throws {
        let inAppEvent = TestInAppEvent(
            name: "some-name",
            data: ErrorData(field: "something", anotherField: "something something")
        )

        let data = InAppEventData(
            event: inAppEvent,
            context: InAppEventContext(
                reportingContext: self.reportingMetadata,
                experimentsReportingData: self.experimentResult.reportingMetadata
            ),
            source: .airship,
            messageID: .airship(identifier: self.scheduleID, campaigns: self.campaigns),
            renderedLocale: self.renderedLocale
        )

        self.eventRecorder.recordEvent(inAppEventData: data)

        XCTAssertTrue(self.analytics.events.isEmpty)
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

    func encode(to encoder: Encoder) throws {
        throw AirshipErrors.error("Failed")
    }
}

