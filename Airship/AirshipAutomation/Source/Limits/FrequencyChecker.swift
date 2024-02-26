/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

public protocol FrequencyCheckerProtocol: Sendable {
    @MainActor
    var isOverLimit: Bool { get }
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

