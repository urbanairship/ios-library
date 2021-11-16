import Foundation

struct ThomasActionRunner : ActionRunnerProtocol {
    func run(_ actions: [String : Any]) {
        ActionRunner.run(actionValues: actions, situation: .manualInvocation, metadata: nil) { result in
            AirshipLogger.trace("Finishing running actions with result: \(result)")
        }
    }
}
