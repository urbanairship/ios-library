/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppEventContext: Encodable, Equatable, Sendable {
    struct Pager: Encodable, Equatable, Sendable {
        var identifier: String
        var pageIdentifier: String
        var pageIndex: Int
        var completed: Bool
        var count: Int

        enum CodingKeys: String, CodingKey {
            case identifier
            case pageIdentifier = "page_identifier"
            case pageIndex = "page_index"
            case completed
            case count
        }
    }

    struct Form: Encodable, Equatable, Sendable {
        var identifier: String
        var submitted: Bool
        var type: String
        var responseType: String?

        enum CodingKeys: String, CodingKey {
            case identifier
            case submitted
            case type
            case responseType = "response_type"
        }
    }

    struct Button: Encodable, Equatable, Sendable {
        var identifier: String

        enum CodingKeys: String, CodingKey {
            case identifier
        }
    }

    enum CodingKeys: String, CodingKey {
        case pager
        case button
        case form
        case reportingContext = "reporting_context"
        case experimentsReportingData = "experiments"
    }

    var pager: Pager?
    var button: Button?
    var form: Form?
    var reportingContext: AirshipJSON?
    var experimentsReportingData: [AirshipJSON]?
}

extension InAppEventContext {

    static func makeContext(
        reportingContext: AirshipJSON?,
        experimentsResult: ExperimentResult?,
        layoutContext: ThomasLayoutContext?
    ) -> InAppEventContext? {
        let pager = makePagerContext(layoutContext: layoutContext)
        let button = makeButtonContext(layoutContext: layoutContext)
        let form = makeFormContext(layoutContext: layoutContext)
        let reportingContext = reportingContext
        let experimentsReportingData = experimentsResult?.reportingMetadata

        guard
            pager == nil,
            button == nil,
            form == nil,
            reportingContext == nil,
            experimentsReportingData?.isEmpty != false
        else {
            return InAppEventContext(
                pager: pager,
                button: button,
                form: form,
                reportingContext: reportingContext,
                experimentsReportingData: experimentsReportingData
            )
        }
        return nil
    }

    private static func makePagerContext(layoutContext: ThomasLayoutContext?) -> InAppEventContext.Pager? {
        guard let info = layoutContext?.pagerInfo else {
            return nil
        }

        return InAppEventContext.Pager(
            identifier: info.identifier,
            pageIdentifier: info.pageIdentifier,
            pageIndex: info.pageIndex,
            completed: info.completed,
            count: info.pageCount
        )
    }

    private static func makeFormContext(layoutContext: ThomasLayoutContext?) -> InAppEventContext.Form? {
        guard let info = layoutContext?.formInfo else {
            return nil
        }

        return InAppEventContext.Form(
            identifier: info.identifier, 
            submitted: info.submitted,
            type: info.formType,
            responseType: info.formResponseType
        )
    }

    private static func makeButtonContext(layoutContext: ThomasLayoutContext?) -> InAppEventContext.Button? {
        guard let info = layoutContext?.buttonInfo else {
            return nil
        }

        return InAppEventContext.Button(
            identifier: info.identifier
        )
    }
}
