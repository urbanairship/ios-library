// Copyright Urban Airship and Contributors

import Foundation

import AirshipCore
import AirshipScenes

@MainActor
final class NativeLayoutPersistentDataStore: LayoutDataStorage {
    let messageID: String

    private var restoreID: String? = nil
    private var storage: [String: Data] = [:]
    private var pendingSaveTask: Task<Void, Never>? = nil

    private let save: @Sendable (MessageCenterMessage.AssociatedData.ViewState?) async -> Void
    private let fetch: @Sendable () async -> MessageCenterMessage.AssociatedData.ViewState?

    init(
        messageID: String,
        onSave: @Sendable @escaping (MessageCenterMessage.AssociatedData.ViewState?) async -> Void,
        onFetch: @Sendable @escaping () async -> MessageCenterMessage.AssociatedData.ViewState?
    ) {
        self.messageID = messageID
        self.save = onSave
        self.fetch = onFetch
    }

    func prepare(restoreID: String) async {
        // Wait for any in-flight save to complete before reading persisted state
        await pendingSaveTask?.value

        self.restoreID = restoreID

        guard let saved = await fetch() else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] no saved state found")
            return
        }

        guard saved.restoreID == restoreID else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] restoreID mismatch: stored=\(saved.restoreID) expected=\(restoreID)")
            self.clear()
            return
        }

        if
            let data = saved.state,
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            for (key, value) in decoded {
                let json = String(data: value, encoding: .utf8) ?? "<non-utf8>"
                AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] loaded key=\(key) value=\(json)")
            }
            self.storage = decoded
        } else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] saved state empty for restoreID=\(restoreID)")
        }
    }

    func store(_ state: Data?, key: String) {
        guard let restoreID else { return }
        storage[key] = state
        let json = state.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] storing key=\(key) value=\(json)")
        let viewState = makeViewState(restoreID: restoreID)
        pendingSaveTask = Task { [save] in
            await save(viewState)
        }
    }

    func retrieve(_ key: String) -> Data? {
        let result = storage[key]
        let json = result.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] retrieve key=\(key) value=\(json)")
        return result
    }

    func clear() {
        storage.removeAll()
        let viewState: MessageCenterMessage.AssociatedData.ViewState? = if let restoreID {
            .init(restoreID: restoreID)
        } else {
            nil
        }
        pendingSaveTask = Task { [save] in
            await save(viewState)
        }
    }

    private func makeViewState(restoreID: String) -> MessageCenterMessage.AssociatedData.ViewState? {
        let data = try? JSONEncoder().encode(storage)
        return .init(restoreID: restoreID, state: data)
    }
}
