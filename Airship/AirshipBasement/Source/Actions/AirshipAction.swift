/* Copyright Airship and Contributors */

import Foundation

/// Airship action. Actions can be registered in the `ActionRegistry` and ran through the `ActionRunner`.
public protocol AirshipAction: AnyObject, Sendable {

     /// Called before an action is performed to determine if the
     /// the action can accept the arguments.
     /// This method can be used both to verify that an argument's value is an appropriate type,
     /// as well as to limit the scope of execution of a desired range of values. Rejecting
     /// arguments will result in the action not being performed when it is run.
     /// - Parameters:
     ///    -   ActionArgument A UAActionArgument value representing the arguments passed to the action.
     ///  - Returns:  YES if the action can perform with the arguments, otherwise NO
    func accepts(arguments: ActionArguments) async -> Bool
    
     /// Performs the action.
     /// You should not ordinarily call this method directly. Instead, use the `ActionRunner`.
     ///  - Parameters:
     ///    - arguments Arguments value representing the arguments passed to the action.
     ///  - Returns:An optional value.
    func perform(arguments: ActionArguments) async throws -> AirshipJSON?
}
