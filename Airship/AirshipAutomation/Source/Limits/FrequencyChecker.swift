/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Protocol for checking and incrementing frequency limits (e.g. for in-app message display caps).
public protocol FrequencyCheckerProtocol: Sendable {
    /// Whether the frequency limit has been exceeded.
    @MainActor
    var isOverLimit: Bool { get }
    /// Checks the limit and, if not over limit, increments the count. Call from main actor.
    /// - Returns: `true` if the increment was applied (under limit), `false` if over limit.
    @MainActor
    func checkAndIncrement() -> Bool
}

final class FrequencyChecker: FrequencyCheckerProtocol {
    private let isOverLimitBlock: @Sendable @MainActor () -> Bool
    private let checkAndIncrementBlock: @Sendable @MainActor () -> Bool

    var isOverLimit: Bool {
        return isOverLimitBlock()
    }

    init(
        isOverLimitBlock: @escaping  @Sendable @MainActor () -> Bool,
        checkAndIncrementBlock: @escaping  @Sendable @MainActor () -> Bool
    ) {
        self.isOverLimitBlock = isOverLimitBlock
        self.checkAndIncrementBlock = checkAndIncrementBlock
    }

    @MainActor
    func checkAndIncrement() -> Bool {
        return checkAndIncrementBlock()
    }
}

