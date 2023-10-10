import Combine
import Foundation

@testable import AirshipCore

class TestWorkManager: AirshipWorkManagerProtocol, @unchecked Sendable {

    
    struct Worker {
        let workID: String
        let type: AirshipWorkerType
        let workHandler: (AirshipWorkRequest) async throws -> AirshipWorkResult
    }
    
    var backgroundWorkRequests: [AirshipWorkRequest] = []

    var rateLimits: [String: RateLimit] = [:]
    var workRequests: [AirshipWorkRequest] = []
    private var workHandler: ((AirshipWorkRequest) async throws -> AirshipWorkResult?)? = nil

    var autoLaunchRequests: Bool = false
    var workers: [Worker] = []
    func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest) async throws -> AirshipWorkResult
    ) {
        self.workers.append(
            Worker(
                workID: workID,
                type: type,
                workHandler: workHandler
            )
        )
        self.workHandler = workHandler
    }
    
    func registerWorker(_ workID: String, type: AirshipCore.AirshipWorkerType, workHandler: @escaping (AirshipCore.AirshipWorkRequest, AirshipCore.AirshipWorkContinuation) -> Void) {
        
    }
    
    func setRateLimit(_ limitID: String, rate: Int, timeInterval: TimeInterval) {
        rateLimits[limitID] = RateLimit(rate: rate, timeInterval: timeInterval)
    }

    func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        workRequests.append(request)
        if (autoLaunchRequests) {
            Task {
                try await workHandler?(request)
            }
        }

    }
    
    func autoDispatchWorkRequestOnBackground(_ request: AirshipWorkRequest) {
        backgroundWorkRequests.append(request)
    }

    func launchTask(request: AirshipWorkRequest) async throws -> AirshipWorkResult? {
        return try await workHandler?(request)
    }

    struct RateLimit {
        let rate: Int
        let timeInterval: TimeInterval
    }
}
