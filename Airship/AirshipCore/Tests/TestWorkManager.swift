import Combine
import Foundation

@testable import AirshipCore

class TestWorkManager: AirshipWorkManagerProtocol {
    struct Worker {
        let workID: String
        let type: AirshipWorkerType
        let workHandler: (AirshipWorkRequest) async throws -> AirshipWorkResult
    }
    
    var workRequests: [AirshipWorkRequest] = []
    private var workHandler: ((AirshipWorkRequest) async throws -> AirshipWorkResult?)? = nil
    
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
    
    func _registerWorker(_ workID: String, type: AirshipCore.AirshipWorkerType, workHandler: @escaping (AirshipCore.AirshipWorkRequest, AirshipCore.AirshipWorkContinuation) -> Void) {
        
    }
    
    func setRateLimit(_ limitID: String, rate: Int, timeInterval: TimeInterval) {
        
    }
    
    func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        workRequests.append(request)
    }
    
    func launchTask(request: AirshipWorkRequest) async throws -> AirshipWorkResult? {
        return try await workHandler?(request)
    }
}
