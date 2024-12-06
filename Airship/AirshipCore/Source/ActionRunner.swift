/* Copyright Airship and Contributors */

/// A helper class for running actions by name or by reference.
public final class ActionRunner: NSObject {

    /// Runs an action
    /// - Parameters:
    ///     - action: The action to run
    ///     - arguments: The action's arguments
    /// - Returns An action result
    public class func run(
        action: any AirshipAction,
        arguments: ActionArguments
    ) async -> ActionResult {
        guard await action.accepts(arguments: arguments) else {
            AirshipLogger.debug(
                "Action \(action) rejected arguments \(arguments)."
            )
            return .argumentsRejected
        }

        do {
            let result = try await action.perform(arguments: arguments) ?? .null
            AirshipLogger.debug(
                "Action \(action) finished with result \(result), argument: \(arguments)."
            )
            return .completed(result)
        } catch {
            AirshipLogger.debug(
                "Action \(action) finished with error \(error), argument: \(arguments)."
            )
            return .error(error)
        }
    }

    /// Runs an action
    /// - Parameters:
    ///     - actionName: The name of the action
    ///     - arguments: The action's arguments
    /// - Returns An action result
    public class func run(
        actionName: String,
        arguments: ActionArguments
    ) async -> ActionResult {
        guard
            let entry = await Airship.actionRegistry.entry(name: actionName)
        else {
            return .actionNotFound
        }

        guard await entry.predicate?(arguments) != false else {
            AirshipLogger.debug(
                "Action \(actionName) predicate rejected argument: \(arguments)."
            )
            return .argumentsRejected
        }

        let action: any AirshipAction = entry.action(situation: arguments.situation)

        return await self.run(
            action: action,
            arguments: arguments
        )
    }

    /// Runs an action
    /// - Parameters:
    ///     - actionsPayload: A map of action name to action value.
    ///     - situation: The action's situation
    ///     - metadata: The action's metadata
    /// - Returns A map of action name to action result
    @discardableResult
    public class func run(
        actionsPayload: AirshipJSON,
        situation: ActionSituation,
        metadata: [String: any Sendable]
    ) async -> [String: ActionResult] {
        guard case .object(let payload) = actionsPayload else {
            AirshipLogger.error("Invalid actions payload: \(actionsPayload)")
            return [:]
        }

        var results: [String: ActionResult] = [:]
        for (key, value) in payload {
            results[key] = await run(
                actionName: key,
                arguments: ActionArguments(
                    value: value,
                    situation: situation,
                    metadata: metadata
                )
            )
        }

        return results
    }

    public class func _run(
        actionsPayload: [String: Any],
        situation: ActionSituation
    ) async {
        guard let value = try? AirshipJSON.wrap(actionsPayload) else {
            AirshipLogger.error("Invalid actions payload: \(actionsPayload)")
            return
        }
        await run(
            actionsPayload: value,
            situation: situation,
            metadata: [:]
        )
    }

}
