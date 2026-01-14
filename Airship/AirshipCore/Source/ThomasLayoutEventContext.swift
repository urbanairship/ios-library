/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct ThomasLayoutEventContext: Encodable, Equatable, Sendable {
    public struct Display: Encodable, Equatable, Sendable {
        public var triggerSessionID: String
        public var isFirstDisplay: Bool
        public var isFirstDisplayTriggerSessionID: Bool
        
        public init(triggerSessionID: String, isFirstDisplay: Bool, isFirstDisplayTriggerSessionID: Bool) {
            self.triggerSessionID = triggerSessionID
            self.isFirstDisplay = isFirstDisplay
            self.isFirstDisplayTriggerSessionID = isFirstDisplayTriggerSessionID
        }

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

public extension ThomasLayoutEventContext {

    static func makeContext(
        reportingContext: AirshipJSON?,
        experimentsResult: ExperimentResult?,
        layoutContext: ThomasLayoutContext?,
        displayContext: ThomasLayoutEventContext.Display?
    ) -> ThomasLayoutEventContext? {
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
            return ThomasLayoutEventContext(
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
