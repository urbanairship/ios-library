import AirshipPreferenceCenter

final class MockPreferenceCenterOpenDelegate: PreferenceCenterOpenDelegate, @unchecked Sendable {
    @MainActor private var lastOpenId: String?
    @MainActor var result: Bool = false
    
    private let lock = AirshipLock()
    private var openPCTask: Task<Void, Never>?

    func openPreferenceCenter(_ identifier: String) -> Bool {
        lock.sync {
            openPCTask = Task { @MainActor in
                self.lastOpenId = identifier
            }
        }
        return false
    }
    
    @MainActor
    func getLastOpenId() async -> String? {
        await lock.sync { openPCTask }?.value
        return lastOpenId
    }
    
    
}
