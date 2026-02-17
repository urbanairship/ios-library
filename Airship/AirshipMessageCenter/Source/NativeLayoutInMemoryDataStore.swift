// Copyright Urban Airship and Contributors


import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class NativeLayoutInMemoryDataStore: LayoutDataStorage {
    let identifier: String
    
    private var storage: [String: Data] = [:]
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func store(_ state: Data?, key: String) {
        self.storage[key] = state
    }
    
    func retrieve(_ key: String) -> Data? {
        return self.storage[key]
    }
    
    func clear() {
        self.storage.removeAll()
    }
}
