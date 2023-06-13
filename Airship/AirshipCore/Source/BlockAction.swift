/* Copyright Airship and Contributors */

import Foundation

/// Action that runs a block.
public final class BlockAction: AirshipAction {

    private let block: @Sendable (ActionArguments) async throws -> AirshipJSON?
    private let predicate: (@Sendable(ActionArguments) async -> Bool)?
    
    /**
     * Block action constructor.
     *  - Parameters:
     *    - predicate: Optional predicate.
     *    - block: The action block.
     */
    public init(
        predicate:(@Sendable(ActionArguments) async -> Bool)? = nil,
        block: @escaping @Sendable (ActionArguments) async throws -> AirshipJSON?) {
            self.predicate = predicate
            self.block = block
        }

    public func accepts(arguments: ActionArguments) async -> Bool {
        return (await self.predicate?(arguments)) ?? true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        return try await self.block(arguments)
    }
}
