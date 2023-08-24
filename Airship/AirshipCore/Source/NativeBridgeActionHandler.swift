/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import WebKit

protocol NativeBridgeActionHandlerProtocol {
    
    /**
     * Runs actions for a command.
     *  - Parameters:
     *    - command The action command.
     *    - metadata The action metadata.
     *  - Returns: Returns the optional script to evaluate in the web view..
     */
    @MainActor
    func runActionsForCommand(
        command: JavaScriptCommand,
        metadata: [String: Sendable]?,
        webView: WKWebView
    ) async -> String?
}

private struct DefaultNativeBridgeActionRunner: NativeBridgeActionRunner {
    func runAction(actionName: String, arguments: ActionArguments, webView: WKWebView) async -> ActionResult {
        return await ActionRunner.run(actionName: actionName, arguments: arguments)
    }
}

class NativeBridgeActionHandler: NativeBridgeActionHandlerProtocol {


    private let actionRunner: NativeBridgeActionRunner

    init(actionRunner: NativeBridgeActionRunner = DefaultNativeBridgeActionRunner()) {
        self.actionRunner = actionRunner
    }

    /**
     * Runs actions for a command.
     *  - Parameters:
     *   - command The action command.
     *   - metadata The action metadata.
     *   - webView The web view
     */
    @MainActor
    public func runActionsForCommand(
        command: JavaScriptCommand,
        metadata: [String: Sendable]?,
        webView: WKWebView
    ) async -> String? {
        AirshipLogger.debug("Running actions for command: \(command)")
        
        /*
         * run-action-cb performs a single action and calls the completion handler with
         * the result of the action. The action's value is JSON encoded.
         *
         * Expected format:
         * run-action-cb/<actionName>/<actionValue>/<callbackID>
         */
        if command.name == "run-action-cb" {
            if command.arguments.count != 3 {
                AirshipLogger.debug(
                    String(
                        format:
                            "Unable to run-action-cb, wrong number of arguments. %@",
                        command.arguments
                    )
                )
                AirshipLogger.error("Unable to run-action-cb, wrong number of arguments")
            }
            
            let actionName = command.arguments[0]
            let actionValue = NativeBridgeActionHandler.parse(
                command.arguments[1]
            )
            let callbackID = command.arguments[2]

            /// Run the action
            return await self.run(
                actionName,
                actionValue,
                metadata ?? [:],
                callbackID,
                webView: webView
            )
        }
        
        /*
         * run-actions performs several actions with the values JSON encoded.
         *
         * Expected format:
         * run-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
         */
        if command.name == "run-actions" {
            await self.run(
                self.decodeActionValues(command, false),
                metadata: metadata,
                webView: webView
            )
            return nil
        }
        
        /*
         * run-basic-actions performs several actions with basic encoded action values.
         *
         * Expected format:
         * run-basic-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
         */
        if command.name == "run-basic-actions" {
                await self.run(
                    self.decodeActionValues(command, true),
                    metadata: metadata,
                    webView: webView
                )
            return nil
        }
        
        return nil
    }

    /**
     * Runs a dictionary of action names to an array of action values.
     *
     * - Parameters:
     *   - actionValues A map of action name to an array of action values.
     *   - metadata Optional metadata to pass to the action arguments.
     */
    @MainActor
    private func run(
        _ actionValues: [String: [AirshipJSON]],
        metadata: [String: Sendable]?,
        webView: WKWebView
    ) async {
        for (actionName, values) in actionValues {
            for value in values {
                _ = await self.actionRunner.runAction(
                    actionName: actionName,
                    arguments: ActionArguments(
                        value: value,
                        situation: .webViewInvocation,
                        metadata: metadata ?? [:]
                    ),
                    webView: webView
                )
            }
        }
    }
    
    /**
     * Runs an action with a given value.
     *
     * - Parameters:
     *   - actionName The name of the action to perform
     *   - actionValue The action argument's value
     *   - metadata Optional metadata to pass to the action arguments.
     *   - callbackID A callback identifier generated in the JS layer. This can be `nil`.
     */
    @MainActor
    private func run(
        _ actionName: String,
        _ actionValue: AirshipJSON,
        _ metadata: [String: Sendable],
        _ callbackID: String,
        webView: WKWebView
    ) async -> String? {
        
        let callbackID = try? JSONUtils.string(
            callbackID,
            options: .fragmentsAllowed
        )
        
        let result = await self.actionRunner.runAction(
            actionName: actionName, 
            arguments:  ActionArguments(
                value: actionValue,
                situation: .webViewInvocation,
                metadata: metadata
            ),
            webView: webView
        )
        guard let callbackID = callbackID else {
            return nil
        }

        switch result {
        case .completed(let value):
            return "UAirship.finishAction(null, \((try? value.toString()) ?? "null"), \(callbackID));"
        case .actionNotFound:
            return errorResponse(
                errorMessage: "No action found with name \(actionName), skipping action.",
                callbackID: callbackID
            )
        case .error(let error):
            return errorResponse(
                errorMessage: error.localizedDescription,
                callbackID: callbackID
            )
        case .argumentsRejected:
            return errorResponse(
                errorMessage: "Action \(actionName) rejected arguments.",
                callbackID: callbackID
            )
        }
    }
    
    private class func parse(_ json: String) -> AirshipJSON {
        do {
            return try AirshipJSON.from(json: json)
        } catch {
            AirshipLogger.warn("Unable to json decode action args \(error), \(json)")
            return AirshipJSON.null
        }
    }

    private func errorResponse(errorMessage: String, callbackID: String) -> String {
        let json = (try? JSONUtils.string(errorMessage, options: .fragmentsAllowed)) ?? ""

        return "var error = new Error(); error.message = \(json); UAirship.finishAction(error, null, \(callbackID));"
    }
    
    /**
     * Checks if a command defines an action.
     * - Parameters:
     *  - command The command.
     * - Returns: `YES` if the command is either `run-actions`, `run-action`, or `run-action-cb`, otherwise `NO`.
     */
    @objc(isActionCommand:)
    public class func isActionCommand(command: JavaScriptCommand) -> Bool {
        let name = command.name
        return
            (name == "run-actions" || name == "run-basic-actions"
            || name == "run-action-cb")
    }
    
    /**
     * Decodes options with basic URL or URL+json encoding
     *
     * - Parameters:
     *   - command The JavaScript command.
     *   - basicEncoding Boolean to select for basic encoding
     * - Returns: A dictionary of action name to an array of action values.
     */
    private func decodeActionValues(
        _ command: JavaScriptCommand,
        _ basicEncoding: Bool
    ) -> [String: [AirshipJSON]] {
        var actionValues: [String: [AirshipJSON]] = [:]

        do {
            try command.options.forEach { (actionName, optionValues) in
                actionValues[actionName] = try optionValues.compactMap { actionArg in
                    if (actionArg.isEmpty) {
                        return AirshipJSON.null
                    }

                    if basicEncoding{
                        return AirshipJSON.string(actionArg)
                    }
                    
                    return try AirshipJSON.from(json: actionArg)
                }
            }
        } catch {
            AirshipLogger.warn("Unable to json decode action args \(error) for command \(command)")
            return [:]
        }

        return actionValues
    }
}

#endif
