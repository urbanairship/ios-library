/* Copyright Airship and Contributors */

import Foundation

struct ThomasActionRunner {
    func run(_ actionsPayload: ActionsPayload?) {
        guard let actionsPayload = actionsPayload else {
            return
        }

        guard let actionValues = actionsPayload.value.unWrap() as? [String : Any] else {
            AirshipLogger.error("Invalid actions payload: \(actionsPayload)")
            return
        }
        
        ActionRunner.run(actionValues: actionValues, situation: .manualInvocation, metadata: nil) { result in
            AirshipLogger.trace("Finishing running actions with result: \(result)")
        }
    }
}
