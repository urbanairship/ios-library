/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
protocol ThomasStateProvider: ObservableObject {
    associatedtype SnapshotType: Codable
    
    var updates: AnyPublisher<any Codable, Never> { get }
    func persistentStateSnapshot() -> SnapshotType
    func restorePersistentState(_ state: SnapshotType)
}

@MainActor
public protocol LayoutDataStorage: Sendable {
    var messageID: String { get }
    
    func prepare(restoreID: String) async
    func store(_ state: Data?, key: String)
    func retrieve(_ key: String) -> Data?
    func clear()
}

/// - Note: for internal use only.  :nodoc:
@MainActor
protocol ThomasStateStorage: Sendable {
    
    func store(_ provider: any ThomasStateProvider, identifier: String)
    
    func retrieve<T: ThomasStateProvider>(
        identifier: String,
        builder: () -> T
    ) -> T
}

/// - Note: for internal use only.  :nodoc:
@MainActor
final class DefaultThomasStateStorage: ThomasStateStorage {
    
    private var store: any LayoutDataStorage
    private var providers: [String: any ThomasStateProvider] = [:]
    private var cancellables: [String: AnyCancellable] = [:]
    
    init(store: any LayoutDataStorage) {
        self.store = store
    }
    
    
    func store(_ provider: any ThomasStateProvider, identifier: String) {
        removeStored(forKey: identifier)
        
        encodeAndSave(provider.persistentStateSnapshot(), identifier: identifier)
        
        let subscription = monitorUpdates(provider, identifier: identifier)
        cancellables[identifier] = subscription
    }
    
    func retrieve<T>(
        identifier: String,
        builder: () -> T
    ) -> T where T : ThomasStateProvider {
        
        //check if we have a cached value
        if let cached = providers[identifier] {
            if let result = cached as? T {
                return result
            } else {
                removeStored(forKey: identifier)
            }
        }
        
        let result = builder()
        if
            let stored = store.retrieve(identifier),
            let state = decodeState(T.SnapshotType.self, data: stored)
        {
            result.restorePersistentState(state)
        }
        
        store(result, identifier: identifier)
        
        return result
    }
    
    private func monitorUpdates(_ provider: any ThomasStateProvider, identifier: String) -> AnyCancellable {
        self.providers[identifier] = provider
        
        return provider.updates
            .sink { [weak self] snapshot in
            self?.encodeAndSave(snapshot, identifier: identifier)
        }
    }
    
    private func removeStored(forKey key: String) {
        cancellables.removeValue(forKey: key)?.cancel()
        providers.removeValue(forKey: key)
    }
    
    private func encodeAndSave(_ snapshot: any Codable, identifier: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            AirshipLogger.warn("Failed to encode state snapshot: \(snapshot)")
            return
        }
        
        self.store.store(data, key: identifier)
    }
    
    private func decodeState<T: Codable>(_ type: T.Type, data: Data) -> T? {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            AirshipLogger.warn("Failed to restore state for type \(type): \(error)")
            return nil
        }
    }
}

