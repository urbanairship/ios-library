/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

class InAppEventContextTest: XCTestCase {

    private let campaigns = try! AirshipJSON.wrap(
        ["campaign1": "data1", "campaign2": "data2"]
    )

    private let scheduleID = UUID().uuidString

    var reportingContext: AirshipJSON?
    var experimentsReportingData: [AirshipJSON]?

    func testJSON() async throws {
        let context = InAppEventContext(
            pager: .init(
                identifier: "pager id",
                pageIdentifier: "page id",
                pageIndex: 1,
                completed: true,
                count: 2
            ),
            button: .init(
                identifier: "button id"
            ),
            form: .init(
                identifier: "form id",
                submitted: true,
                type: "form type"
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
                 "count":2
              },
              "experiments":[
                 "experiment result 1",
                 "experiment result 2"
              ]
           }
        """

        let string = try AirshipJSON.wrap(context).toString()

        AirshipLogger.error("\(string)")

        XCTAssertEqual(try AirshipJSON.wrap(context), try AirshipJSON.from(json: expectedJSON))
    }

    func testMake() throws {
        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "some contact",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("some reporting")]
        )

        let reportingMetadata = AirshipJSON.string("reporting info")

        let thomasLayoutContext  = ThomasLayoutContext(
            formInfo: ThomasFormInfo(
                identifier: UUID().uuidString,
                submitted: true,
                formType: UUID().uuidString,
                formResponseType: UUID().uuidString
            ),
            pagerInfo: ThomasPagerInfo(
                identifier: UUID().uuidString,
                pageIndex: 1,
                pageIdentifier: UUID().uuidString,
                pageCount: 2,
                completed: false
            ),
            buttonInfo: ThomasButtonInfo(identifier: UUID().uuidString)
        )

        let context = InAppEventContext.makeContext(
            reportingContext: reportingMetadata,
            experimentsResult: experimentResult,
            layoutContext: thomasLayoutContext
        )

        let expected = InAppEventContext(
            pager: .init(
                identifier: thomasLayoutContext.pagerInfo!.identifier,
                pageIdentifier: thomasLayoutContext.pagerInfo!.pageIdentifier,
                pageIndex: thomasLayoutContext.pagerInfo!.pageIndex,
                completed: thomasLayoutContext.pagerInfo!.completed,
                count: thomasLayoutContext.pagerInfo!.pageCount
            ),
            button: .init(
                identifier: thomasLayoutContext.buttonInfo!.identifier
            ),
            form: .init(
                identifier: thomasLayoutContext.formInfo!.identifier,
                submitted: thomasLayoutContext.formInfo!.submitted,
                type: thomasLayoutContext.formInfo!.formType,
                responseType: thomasLayoutContext.formInfo!.formResponseType

            ),
            reportingContext: reportingMetadata,
            experimentsReportingData: experimentResult.reportingMetadata
        )

        XCTAssertEqual(context, expected)
    }

    func testMakeEmpty() throws {
        let context = InAppEventContext.makeContext(
            reportingContext: nil,
            experimentsResult: nil,
            layoutContext: nil
        )

        XCTAssertNil(context)
    }
}

