/* Copyright Airship and Contributors */

/// A helper class for running actions by name or by reference.
@objc(UAActionRunner)
public class ActionRunner: NSObject {
    
    /**
     * Runs a registered action with the given name.
     *
     * If the action is not registered the completion handler
     * will be called immediately with emptyResult.
     *
     * - Parameters:
     *   - actionName: The name of the action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation
     */
    @objc(runActionWithName:value:situation:)
    public class func run(
        _ actionName: String,
        value: Any?,
        situation: Situation
    ) {
        Task {
            self.run(
                actionName,
                value: value,
                situation: situation,
                metadata: nil
            )
        }
    }
    
    /**
     * Runs a registered action with the given name.
     *
     * If the action is not registered the completion handler
     * will be called immediately with emptyResult.
     *
     * - Parameters:
     *   - actionName: The name of the action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - metadata: The action argument's metadata.
     */
    @objc(runActionWithName:value:situation:metadata:)
    public class func run(
        _ actionName: String,
        value: Any?,
        situation: Situation,
        metadata: [AnyHashable: Any]?
    ) {
        Task {
            self.run(
                actionName,
                value: value,
                situation: situation,
                metadata: metadata
            )
        }
    }
    
    /**
     * Runs a registered action with the given name.
     *
     * If the action is not registered the completion handler
     * will be called immediately with emptyResult.
     *
     * - Parameters:
     *   - actionName: The name of the action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - completionHandler: The completion handler.
     */
    @objc(runActionWithName:value:situation:completionHandler:)
    public class func run(
        _ actionName: String,
        value: Any?,
        situation: Situation) async -> ActionResult {
        return await self.run(
            actionName,
            value: value,
            situation: situation,
            metadata: nil
        )
    }
    
    /**
     * Runs a registered action with the given name.
     *
     * If the action is not registered the completion handler
     * will be called immediately with emptyResult.
     *
     * - Parameters:
     *   - actionName: The name of the action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - metadata: The action argument's metadata.
     *   - completionHandler: The completion handler.
     */
    @objc(runActionWithName:value:situation:metadata:completionHandler:)
    public class func run(
        _ actionName: String,
        value: Any?,
        situation: Situation,
        metadata: [AnyHashable: Any]?) async -> ActionResult {
        guard
            let entry = Airship.shared.actionRegistry.registryEntry(actionName)
        else {
            AirshipLogger.debug(
                "No action found with name \(actionName), skipping action."
            )
            return ActionResult.actionNotFound()
        }
        
        return await self.run(
            actionName,
            entry: entry,
            value: value,
            situation: situation,
            metadata: metadata
        )
    }
    
    /**
     * Runs an action.
     *
     * - Parameters:
     *   - action: The action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     */
    @objc(runAction:value:situation:)
    public class func run(_ action: Action, value: Any?, situation: Situation) {
        Task {
            self.run(
                action,
                value: value,
                situation: situation,
                metadata: nil
            )
        }
    }
    
    /**
     * Runs an action.
     *
     * - Parameters:
     *   - action: The action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - metadata: The action argument's metadata.
     */
    @objc(runAction:value:situation:metadata:)
    public class func run(
        _ action: Action,
        value: Any?,
        situation: Situation,
        metadata: [AnyHashable: Any]?
    ) {
        Task {
            self.run(
                action,
                value: value,
                situation: situation,
                metadata: metadata
            )
        }
    }
    
    /**
     * Runs an action.
     *
     * - Parameters:
     *   - action: The action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - completionHandler: The completion handler.
     */
    @objc(runAction:value:situation:completionHandler:)
    public class func run(
        _ action: Action,
        value: Any?,
        situation: Situation) async -> ActionResult {
        return await self.run(
            action,
            value: value,
            situation: situation,
            metadata: nil
        )
    }
    
    /**
     * Runs an action.
     *
     * - Parameters:
     *   - action: The action.
     *   - value: The action argument's value.
     *   - situation: The action argument's situation.
     *   - metadata: The action argument's metadata.
     *   - completionHandler: The completion handler.
     */
    @objc(runAction:value:situation:metadata:completionHandler:)
    public class func run(
        _ action: Action,
        value: Any?,
        situation: Situation,
        metadata: [AnyHashable: Any]?) async -> ActionResult {
        let arguments = ActionArguments(
            value: value,
            with: situation,
            metadata: metadata
        )
        return await self.run(action, args: arguments)
    }
    
    /**
     * Runs all actions in a given dictionary. The dictionary's keys will be treated
     * as action names, while the values will be treated as each action's argument value.
     *
     * The results of all the actions will be aggregated into a
     * single UAAggregateActionResult.
     *
     * - Parameters:
     *   - actionValues: The map of action names to action values.
     *   - situation: The action argument's situation.
     *   - metadata: The action argument's metadata.
     *   - completionHandler: The completion handler.
     */
    @objc(runActionsWithActionValues:situation:metadata:completionHandler:)
    public class func run(
        actionValues: [AnyHashable: Any],
        situation: Situation,
        metadata: [AnyHashable: Any]?) async -> ActionResult {
            let aggregateResult = AggregateActionResult()
            
            var entries: Set<ActionRegistryEntry> = Set()
            
            for (name, value) in actionValues {
                if let actionName = name as? String {
                    if let entry = Airship.shared.actionRegistry.registryEntry(
                        actionName
                    ) {
                        if !entries.contains(entry) {
                            entries.insert(entry)
                            let result = await self.run(
                                actionName,
                                entry: entry,
                                value: value,
                                situation: situation,
                                metadata: metadata
                            )
                            aggregateResult.add(result, actionName: actionName)
                        }
                    }
                }
            }
            
            return aggregateResult
    }
    
    private class func run(
        _ actionName: String,
        entry: ActionRegistryEntry,
        value: Any?,
        situation: Situation,
        metadata: [AnyHashable: Any]?) async -> ActionResult {
            
            // Add the action name to the metadata
            var fullMetadata: [AnyHashable: Any] = metadata ?? [:]
            fullMetadata[UAActionMetadataRegisteredName] = actionName
            let args = ActionArguments(
                value: value,
                with: situation,
                metadata: fullMetadata
            )
            if entry.predicate?(args) == false {
                AirshipLogger.debug(
                    "Predicate for action \(actionName) rejected args \(args)."
                )
                return ActionResult.rejectedArguments()
            } else {
                return await self.run(
                    entry.action(situation: situation),
                    args: args
                )
            }
        }
    
    private class func run(
        _ action: Action,
        args: ActionArguments) async -> ActionResult {
            guard action.acceptsArguments(args) else {
                AirshipLogger.debug(
                    "Action \(action) rejected arguments \(args)."
                )
                return ActionResult.rejectedArguments()
            }
            
            AirshipLogger.debug(
                "Action \(action) performing with arguments \(args)."
            )
            action.willPerform?(with: args)
            let result = await action.perform(with: args)
            action.didPerform?(with: args, with: result)
            return result
        }
}
