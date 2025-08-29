/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppEventContext: Encodable, Equatable, Sendable {
    struct Display: Encodable, Equatable, Sendable {
        var triggerSessionID: String
        var isFirstDisplay: Bool
        var isFirstDisplayTriggerSessionID: Bool


        enum CodingKeys: String, CodingKey {
            case triggerSessionID = "trigger_session_id"
            case isFirstDisplay = "is_first_display"
            case isFirstDisplayTriggerSessionID = "is_first_display_trigger_session"
        }
    }

    enum CodingKeys: String, CodingKey {
        case pager
        case button
        case form
        case reportingContext = "reporting_context"
        case experimentsReportingData = "experiments"
        case display
    }

    var pager: ThomasLayoutContext.Pager?
    var button:  ThomasLayoutContext.Button?
    var form:  ThomasLayoutContext.Form?
    var display: Display?

    var reportingContext: AirshipJSON?
    var experimentsReportingData: [AirshipJSON]?
}

extension InAppEventContext {

    static func makeContext(
        reportingContext: AirshipJSON?,
        experimentsResult: ExperimentResult?,
        layoutContext: ThomasLayoutContext?,
        displayContext: InAppEventContext.Display?
    ) -> InAppEventContext? {
        let pager = layoutContext?.pager
        let button = layoutContext?.button
        let form = layoutContext?.form
        let reportingContext = reportingContext
        let experimentsReportingData = experimentsResult?.reportingMetadata

        guard
            pager == nil,
            button == nil,
            form == nil,
            reportingContext == nil,
            experimentsReportingData?.isEmpty != false,
            displayContext == nil
        else {
            return InAppEventContext(
                pager: pager,
                button: button,
                form: form,
                display: displayContext,
                reportingContext: reportingContext,
                experimentsReportingData: experimentsReportingData
            )
        }
        return nil
    }
}
