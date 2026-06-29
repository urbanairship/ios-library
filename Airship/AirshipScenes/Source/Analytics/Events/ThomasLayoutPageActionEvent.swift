/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

struct ThomasLayoutPageActionEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppPageAction
    public let data: (any Sendable & Encodable)?
    
    public init(data: ThomasReportingEvent.PageActionEvent) {
        self.data = data
    }
}
