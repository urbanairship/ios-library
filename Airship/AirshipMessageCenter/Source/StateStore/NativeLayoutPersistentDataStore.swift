// Copyright Urban Airship and Contributors

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class NativeLayoutPersistentDataStore: LayoutDataStorage {
    let messageID: String
    
    private var restoreID: String? = nil
    private var storage: [String: Data] = [:]
    
    private let save: @Sendable (MessageCenterMessage.AssociatedData.ViewState?) -> Void
    private let fetch: @Sendable () async -> MessageCenterMessage.AssociatedData.ViewState?
    
    init(
        messageID: String,
        onSave: @Sendable @escaping (MessageCenterMessage.AssociatedData.ViewState?) -> Void,
        onFetch: @Sendable @escaping () async -> MessageCenterMessage.AssociatedData.ViewState?
    ) {
        self.messageID = messageID
        self.save = onSave
        self.fetch = onFetch
    }
    
    func prepare(restoreID: String) async {
        self.restoreID = restoreID
        
        guard
            let saved = await fetch(),
            saved.restoreID == restoreID
        else {
            self.clear()
            return
        }
        
        if
            let data = saved.state,
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            self.storage = decoded
        }
    }
    
    func store(_ state: Data?, key: String) {
        guard let restoreID else { return }
        
        self.storage[key] = state
        
        let state = makeViewState(restoreID: restoreID)
        storeState(state)
    }
    
    func retrieve(_ key: String) -> Data? {
        //assume storage is preloaded
        return self.storage[key]
    }
    
    func clear() {
        self.storage.removeAll()
        
        if let restoreID {
            storeState(.init(restoreID: restoreID))
        } else {
            storeState(nil)
        }
    }
    
    private func storeState(_ state: MessageCenterMessage.AssociatedData.ViewState?) {
        save(state)
    }
    
    private func makeViewState(restoreID: String) -> MessageCenterMessage.AssociatedData.ViewState? {
        let data = try? JSONEncoder().encode(self.storage)
        
        return .init(
            restoreID: restoreID,
            state: data
        )
    }
}
