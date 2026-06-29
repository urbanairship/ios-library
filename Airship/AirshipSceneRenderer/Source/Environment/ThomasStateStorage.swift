/* Copyright Airship and Contributors */

public import Foundation
import Combine
@_spi(AirshipInternal) import AirshipBasement

@MainActor
protocol ThomasStateProvider: ObservableObject {
    associatedtype SnapshotType: Codable

    var updates: AnyPublisher<any Codable, Never> { get }
    func persistentStateSnapshot() -> SnapshotType
    func restorePersistentState(_ state: SnapshotType)
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public protocol LayoutDataStorage: Sendable {
    var messageID: String { get }

    func prepare(restoreID: String) async
    func store(_ state: Data?, key: String)
    func retrieve(_ key: String) -> Data?
    func clear()
}

@MainActor
protocol ThomasStateStorage: Sendable {

    func store(_ provider: any ThomasStateProvider, identifier: String)

    func retrieve<T: ThomasStateProvider>(
        identifier: String,
        builder: () -> T
    ) -> T

    func flush()
}

@MainActor
final class DefaultThomasStateStorage: ThomasStateStorage {

    private static let debounceInterval: TimeInterval = 0.5

    private var store: any LayoutDataStorage
    private var providers: [String: any ThomasStateProvider] = [:]
    private var cancellables: [String: AnyCancellable] = [:]
    private var pendingData: [String: Data] = [:]
    private var pendingSaveTask: Task<Void, Never>? = nil
    private let taskSleeper: any AirshipTaskSleeper

    init(store: any LayoutDataStorage, taskSleeper: any AirshipTaskSleeper = .shared) {
        self.store = store
        self.taskSleeper = taskSleeper
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
            AirshipLogger.debug("StateStorage[\(identifier)] restoring from persisted data")
            result.restorePersistentState(state)
        } else {
            AirshipLogger.debug("StateStorage[\(identifier)] no persisted data — creating fresh")
        }

        store(result, identifier: identifier)

        return result
    }

    func flush() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        flushPendingData()
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

        pendingData[identifier] = data
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSaveTask?.cancel()
        // Strong capture keeps this object alive for the debounce window so
        // state written after dismiss (e.g. form status set to .submitted after
        // the flush in tryDismiss) still reaches the persistent store.
        pendingSaveTask = Task { [self] in
            try? await taskSleeper.sleep(timeInterval: DefaultThomasStateStorage.debounceInterval)
            guard !Task.isCancelled else { return }
            flushPendingData()
        }
    }

    private func flushPendingData() {
        let pending = pendingData
        pendingData.removeAll()
        for (key, data) in pending {
            store.store(data, key: key)
        }
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
