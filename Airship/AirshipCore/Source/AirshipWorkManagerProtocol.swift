/* Copyright Airship and Contributors */

public import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AirshipWorkManagerProtocol: Sendable {
    func registerWorker(
        _ workID: String,
        workHandler: @Sendable @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    )

    func setRateLimit(
        _ limitID: String,
        rate: Int,
        timeInterval: TimeInterval
    )

    func dispatchWorkRequest(
        _ request: AirshipWorkRequest
    )

    @MainActor
    func autoDispatchWorkRequestOnBackground(
        _ request: AirshipWorkRequest
    )
}
