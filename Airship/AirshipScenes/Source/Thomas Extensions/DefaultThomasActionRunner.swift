/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import AirshipBasement

/// The action runner the SDK wires up by default — runs actions through the global `ActionRunner`.
/// Hosts that need per-message reporting (e.g. IAA) inject their own.
@MainActor
struct DefaultThomasActionRunner: ThomasActionRunner {
    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext) {
        Task {
            await ActionRunner.run(
                actionsPayload: actions,
                situation: .automation,
                metadata: [:]
            )
        }
    }

    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult {
        await ActionRunner.run(actionName: actionName, arguments: arguments)
    }
}
