/* Copyright Airship and Contributors */

#if !os(tvOS)

import Foundation

@objc (UANativeBridgeActionHandlerProtocol)
public protocol NativeBridgeActionHandlerProtocol {
    
    /**
     * Runs actions for a command.
     *  - Parameters:
     *    - command The action command.
     *    - metadata The action metadata.
     *    - completionHandler The completion handler with optional script to evaluate in the web view..
     */
    @objc(runActionsForCommand:metadata:completionHandler:)
    func runActionsForCommand(command: JavaScriptCommand, metadata: [AnyHashable : Any]?, completionHandler: @escaping (String?) -> Void)
    
}

@objc(NativeBridgeActionHandler)
public class NativeBridgeActionHandler : NSObject, NativeBridgeActionHandlerProtocol {
    
    /**
     * Runs actions for a command.
     *  - Parameters:
     *   - command The action command.
     *   - metadata The action metadata.
     *   - completionHandler The completion handler with optional script to evaluate in the web view..
     */
    @objc(runActionsForCommand:metadata:completionHandler:)
    public func runActionsForCommand(command: JavaScriptCommand, metadata: [AnyHashable : Any]?, completionHandler: @escaping (String?) -> Void) {
        
        AirshipLogger.debug(String(format: "action js delegate name: %@ \n arguments: %@ \n options: %@", command.name ?? "", command.arguments, command.options))
        /*
         * run-action-cb performs a single action and calls the completion handler with
         * the result of the action. The action's value is JSON encoded.
         *
         * Expected format:
         * run-action-cb/<actionName>/<actionValue>/<callbackID>
         */
        if (command.name == "run-action-cb") {
            if (command.arguments.count != 3) {
                AirshipLogger.debug(String(format: "Unable to run-action-cb, wrong number of arguments. %@", command.arguments))
                completionHandler(nil)
                return
            }
            
            let actionName = command.arguments[0]
            let actionValue = NativeBridgeActionHandler.parse(command.arguments[1])
            let callbackID = command.arguments[2]
            
            /// Run the action
            self.run(actionName, actionValue, metadata, callbackID, completionHandler)
            return
        }
        
        /*
         * run-actions performs several actions with the values JSON encoded.
         *
         * Expected format:
         * run-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
         */
        if (command.name == "run-actions") {
            self.run(self.decodeActionValues(command, false), metadata: metadata)
            completionHandler(nil)
            return
        }
    
        /*
         * run-basic-actions performs several actions with basic encoded action values.
         *
         * Expected format:
         * run-basic-actions?<actionName>=<actionValue>&<anotherActionName>=<anotherActionValue>...
         */
        if (command.name == "run-basic-actions") {
            self.run(self.decodeActionValues(command, true), metadata: metadata)
            completionHandler(nil)
            return
        }
        
        completionHandler(nil)
        return
    }
    
    /**
     * Runs a dictionary of action names to an array of action values.
     *
     * - Parameters:
     *   - actionValues A map of action name to an array of action values.
     *   - metadata Optional metadata to pass to the action arguments.
     */
    private func run(_ actionValues: [String: Array <Any?>], metadata: [AnyHashable : Any]?) {
        for (actionName, values) in actionValues {
            for actionValue in values {
                ActionRunner.run(actionName, value: actionValue, situation: .webViewInvocation, metadata: metadata, completionHandler: { result in
                    if (result.status == .completed) {
                        AirshipLogger.debug(String(format:"action %@ completed successfully", actionName))
                    } else {
                        AirshipLogger.debug(String(format:"action %@ completed with an error", actionName))
                    }
                })
            }
        }
    }
    
    /**
     * Runs an action with a given value and performs a callback on completion.
     *
     * - Parameters:
     *   - actionName The name of the action to perform
     *   - actionValue The action argument's value
     *   - metadata Optional metadata to pass to the action arguments.
     *   - callbackID A callback identifier generated in the JS layer. This can be `nil`.
     *   - completionHandler The completion handler passed in the JS delegate call.
     */
    private func run(_ action: String, _ actionValue: Any?, _ metadata: [AnyHashable : Any]?, _ callbackID: String, _ completionHandler: @escaping (String?) -> Void) {
        let callbackID = try? JSONUtils.string(callbackID, options: .fragmentsAllowed)
        
        let actionCompletionHandler: (ActionResult) -> Void = { result in
            AirshipLogger.debug(String(format:"Action %@ finished executing with status %ld", action, result.status.rawValue))
            guard let callbackID = callbackID else {
                completionHandler(nil)
                return
            }
            
            var script: String?
            var resultString: String?
            var errorMessage: String?
            
            switch result.status {
            case .completed:
                if (result.value != nil) {
                    ///if the action completed with a result value, serialize into JSON
                    ///accepting fragments so we can write lower level JSON values
                    do {
                        resultString = try JSONUtils.string(result.value!, options: .fragmentsAllowed)
                    }
                    catch {
                        AirshipLogger.error("Unable to serialize result value, falling back to string description")
                        /// JSONify the result string
                        resultString = try? JSONUtils.string(String(describing: result.value!), options: .fragmentsAllowed)
                    }
                }
                ///in the case where there is no result value, pass null
                resultString = resultString ?? "null"
                break
            case .actionNotFound:
                errorMessage = String(format:"No action found with name %@, skipping action.", action)
                break
            case .error:
                errorMessage = result.error?.localizedDescription
                break
            case .argumentsRejected:
                errorMessage =  String(format:"Action %@ rejected arguments.", action)
                break
            @unknown default:
                return
            }
            
            if (errorMessage != nil) {
                /// JSONify the error message
                errorMessage = try? JSONUtils.string(errorMessage!, options: .fragmentsAllowed)
                script = String(format:"var error = new Error(); error.message = %@; UAirship.finishAction(error, null, %@);", errorMessage!, callbackID)
            } else if (resultString != nil) {
                script = String(format:"UAirship.finishAction(null, %@, %@);", resultString!, callbackID)
            }
       
            completionHandler(script)
        }
        
        ActionRunner.run(action, value: actionValue, situation: .webViewInvocation, metadata: metadata, completionHandler: actionCompletionHandler)
    }
    
    private class func parse(_ arguments: String) -> Any? {
        /// allow the reading of fragments so we can parse lower level JSON values
        let jsonDecodedArgs = try? JSONUtils.object(arguments, options: [.mutableContainers, .allowFragments])
        if (jsonDecodedArgs == nil){
            AirshipLogger.debug("unable to json decode action args")
        }
        return jsonDecodedArgs
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
        return (name == "run-actions" || name == "run-basic-actions" || name == "run-action-cb")
    }
    
    /**
     * Decodes options with basic URL or URL+json encoding
     *
     * - Parameters:
     *   - command The JavaScript command.
     *   - basicEncoding Boolean to select for basic encoding
     * - Returns: A dictionary of action name to an array of action values.
     */
    private func decodeActionValues(_ command: JavaScriptCommand, _ basicEncoding: Bool) -> [String : Array <Any?>] {
        if (command.options.count == 0) {
            AirshipLogger.error("Error no options available to decode")
            return [:]
        }
        
        var actionValues: [String: Array <Any?>] = [:]

        for (actionName, optionValues) in command.options {
            var values: Array <Any?> = []
        
            for actionArg in optionValues as! [Any?] {
                guard let actionArg = actionArg as? String else {
                    values.append(nil)
                    continue
                }
                
                var value: Any?
                
                if (basicEncoding || actionArg.count == 0) {
                    value = actionArg
                }
                else {
                    value = NativeBridgeActionHandler.parse(_:actionArg)
                }
                
                if (value == nil) {
                    AirshipLogger.error(String(format:"Error decoding arguments: %@", actionArg))
                    return [:]
                }
                
                values.append(value)
            }
            
            actionValues[actionName as! String] = values
        }
       return actionValues
    }
}

#endif

