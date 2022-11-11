import Foundation

@objc
public protocol AirshipWorkManagerBaseProtocol {
    @objc(registerWorkerWithForID:type:workHandler:)
    func _registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (
            AirshipWorkRequest,
            AirshipWorkContinuation
        ) -> Void
    )

    @objc
    func setRateLimit(
        _ limitID: String,
        rate: Int,
        timeInterval: TimeInterval
    )

    @objc
    func dispatchWorkRequest(
        _ request: AirshipWorkRequest
    )
}

public protocol AirshipWorkManagerProtocol: AirshipWorkManagerBaseProtocol {
    func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    )
}
