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

    func setConstraints(_ constraints: [FrequencyConstraint]) async throws {
        self.constraints = constraints
    }

    func getFrequencyChecker(constraintIDs: [String]?) async throws -> FrequencyCheckerProtocol? {
        guard let constraintIDs = constraintIDs, !constraintIDs.isEmpty else {
            return nil
        }

        return try await self.checkerBlock!(constraintIDs)
    }

}
