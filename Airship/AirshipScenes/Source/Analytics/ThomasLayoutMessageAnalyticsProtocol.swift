@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasLayoutMessageAnalyticsProtocol: AnyObject, Sendable {
    @MainActor
    func recordEvent(
        _ event: any ThomasLayoutEvent,
        layoutContext: ThomasLayoutContext?
    )
}
