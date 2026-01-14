/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

struct ThomasLayoutEventContextTest {

    private let campaigns = try! AirshipJSON.wrap(
        ["campaign1": "data1", "campaign2": "data2"]
    )

    private let scheduleID = UUID().uuidString

    @Test
    func testJSON() async throws {
        let context = ThomasLayoutEventContext(
            pager: ThomasLayoutContext.Pager(
                identifier: "pager id",
                pageIdentifier: "page id",
                pageIndex: 1,
                completed: true,
                count: 2,
                pageHistory: [.init(identifier: "foo-0", index: 0, displayTime: 20)]
            ),
            button: ThomasLayoutContext.Button(
                identifier: "button id"
            ),
            form: ThomasLayoutContext.Form(
                identifier: "form id",
                submitted: true,
                type: "form type"
            ),
            display: .init(
                triggerSessionID: "trigger session id",
                isFirstDisplay: false,
                isFirstDisplayTriggerSessionID: true
            ),
            reportingContext: .string("reporting context"),
            experimentsReportingData: [
                .string("experiment result 1"),
                .string("experiment result 2")
            ]
        )

        let expectedJSON = """
           {
              "reporting_context":"reporting context",
              "form":{
                 "type":"form type",
                 "identifier":"form id",
                 "submitted":true
              },
              "button":{
                 "identifier":"button id"
              },
              "pager":{
                 "page_identifier":"page id",
                 "page_index":1,
                 "identifier":"pager id",
                 "completed":true,
                 "count":2,
                 "page_history": [
                    {
                        "page_identifier": "foo-0",
                        "page_index": 0,
                        "display_time": "20.00"
                    }
                 ]
              },
              "experiments":[
                 "experiment result 1",
                 "experiment result 2"
              ],
              "display":{
                 "trigger_session_id":"trigger session id",
                 "is_first_display":false,
                 "is_first_display_trigger_session":true
              }
           }
        """

        let string = try AirshipJSON.wrap(context).toString()

        AirshipLogger.error("\(string)")

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try AirshipJSON.wrap(context)
        #expect(actual == expected)
    }

    @Test
    func testMake() throws {
        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "some contact",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("some reporting")]
        )

        let reportingMetadata = AirshipJSON.string("reporting info")

        let thomasLayoutContext = ThomasLayoutContext(
            pager: ThomasLayoutContext.Pager(
                identifier: UUID().uuidString,
                pageIdentifier: UUID().uuidString,
                pageIndex: 1,
                completed: false,
                count: 2
            ),
            button: ThomasLayoutContext.Button(identifier: UUID().uuidString),
            form: ThomasLayoutContext.Form(
                identifier: UUID().uuidString,
                submitted: false,
                type: UUID().uuidString,
                responseType: UUID().uuidString
            )
        )

        let displayContext = ThomasLayoutEventContext.Display(
            triggerSessionID: UUID().uuidString,
            isFirstDisplay: true,
            isFirstDisplayTriggerSessionID: false
        )

        let context = ThomasLayoutEventContext.makeContext(
            reportingContext: reportingMetadata,
            experimentsResult: experimentResult,
            layoutContext: thomasLayoutContext,
            displayContext: displayContext
        )

        let expected = ThomasLayoutEventContext(
            pager: thomasLayoutContext.pager,
            button: thomasLayoutContext.button,
            form: thomasLayoutContext.form,
            display: displayContext,
            reportingContext: reportingMetadata,
            experimentsReportingData: experimentResult.reportingMetadata
        )

        #expect(context == expected)
    }

    @Test
    func testMakeEmpty() throws {
        let context = ThomasLayoutEventContext.makeContext(
            reportingContext: nil,
            experimentsResult: nil,
            layoutContext: nil,
            displayContext: nil
        )

        #expect(context == nil)
    }
}

