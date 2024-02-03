/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol AirshipWorkManagerProtocol: Sendable {
    func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest) async throws ->
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

    func autoDispatchWorkRequestOnBackground(
        _ request: AirshipWorkRequest
    )
}
