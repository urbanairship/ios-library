/* Copyright Airship and Contributors */

class FrequencyChecker : NSObject {

    private var overLimitBlock:()->Bool
    private var checkAndIncrementBlock:() async ->Bool

    init(
        overLimitBlock: @escaping () -> Bool,
        checkAndIncrement checkAndIncrementBlock: @escaping () async -> Bool
    ) {
        self.overLimitBlock = overLimitBlock
        self.checkAndIncrementBlock = checkAndIncrementBlock
    }
    
    /// Checks if the frequency constraints are over the limit.
    /// - Returns `true` if the frequency constraints are over the limit, `flase` otherwise.
    func isOverLimit() -> Bool {
        return self.overLimitBlock()
    }

    /// Checks if the frequency constraints are over the limit before incrementing the count towards the constraints.
    /// - Returns `true` if the constraints are not over the limit and the count was incremented, `flase` otherwise.
    func checkAndIncrement() async -> Bool {
        return await self.checkAndIncrementBlock()
    }
}
