import Combine
import Foundation

@testable import AirshipCore

class TestWorkManager: AirshipWorkManagerProtocol {
    struct Worker {
        let workID: String
        let type: AirshipWorkerType
        let workHandler: (AirshipWorkRequest) async throws -> AirshipWorkResult
    }
    
    let rateLimitor = TestWorkRateLimiter()
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
    
    func registerWorker(_ workID: String, type: AirshipCore.AirshipWorkerType, workHandler: @escaping (AirshipCore.AirshipWorkRequest, AirshipCore.AirshipWorkContinuation) -> Void) {
        
    }
    
    func setRateLimit(_ limitID: String, rate: Int, timeInterval: TimeInterval) {
    }
    
    func setRateLimit(_ limitID: String, rate: Int, timeInterval: TimeInterval) async throws {
        try? await self.rateLimitor.set(
            limitID,
            rate: rate,
            timeInterval: timeInterval
        )
    }
    
    func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        workRequests.append(request)
    }
    
    func launchTask(request: AirshipWorkRequest) async throws -> AirshipWorkResult? {
        return try await workHandler?(request)
    }
}
