/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipAutomationSwift
@testable import AirshipCore


final actor TestFrequencyLimitManager: FrequencyLimitManagerProtocol {
    private var constraints: [FrequencyConstraint] = []


    private var checkerBlock: (@Sendable ([String]) async throws -> FrequencyCheckerProtocol)?


    func setCheckerBlock(_ checkerBlock: @Sendable @escaping ([String]) -> FrequencyCheckerProtocol) {
        self.checkerBlock = checkerBlock
    }

    private var onConstraints: (@Sendable ([FrequencyConstraint]) async throws -> Void)?
    func setOnConstraints(_ onConstraints: @escaping @Sendable ([FrequencyConstraint]) async throws -> Void) {
        self.onConstraints = onConstraints
    }
    func setConstraints(_ constraints: [FrequencyConstraint]) async throws {
        self.constraints = constraints
        try await onConstraints?(constraints)
    }

    func getFrequencyChecker(constraintIDs: [String]?) async throws -> FrequencyCheckerProtocol? {
        guard let constraintIDs = constraintIDs, !constraintIDs.isEmpty else {
            return nil
        }

        return try await self.checkerBlock!(constraintIDs)
    }

}

final class TestFrequencyChecker: FrequencyCheckerProtocol, @unchecked Sendable {
    var isOverLimit: Bool = false
    var checkAndIncrementBlock: (() -> Bool)?
    var checkAndIncrementCalled: Bool = false

    func checkAndIncrement() -> Bool {
        checkAndIncrementCalled = true
        return checkAndIncrementBlock!()
    }

    @MainActor
    func setIsOverLimit(_ isOverLimit: Bool) {
        self.isOverLimit = isOverLimit
    }

}

