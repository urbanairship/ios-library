/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol DisplayCoordinatorManagerProtocol: Sendable, AnyObject {
    @MainActor
    var displayInterval: TimeInterval { get set }
    func displayCoordinator(message: InAppMessage) -> any DisplayCoordinator
}

final class DisplayCoordinatorManager: DisplayCoordinatorManagerProtocol {
    private let immediateCoordinator: ImmediateDisplayCoordinator
    private let defaultCoordinator: DefaultDisplayCoordinator
    private let embeddedCoordinator: EmbeddedDisplayCoordinator
    private let dataStore: PreferenceDataStore

    private static let displayIntervalKey: String = "UAInAppMessageManagerDisplayInterval"

    @MainActor
    var displayInterval: TimeInterval {
        get {
            self.dataStore.double(forKey: Self.displayIntervalKey, defaultValue: 0.0)
        }
        set {
            self.dataStore.setDouble(newValue, forKey: Self.displayIntervalKey)
            self.defaultCoordinator.displayInterval = newValue
        }
    }

    @MainActor
    init(
        dataStore: PreferenceDataStore,
        immediateCoordinator: ImmediateDisplayCoordinator? = nil,
        defaultCoordinator: DefaultDisplayCoordinator? = nil,
        embeddedCoordinator: EmbeddedDisplayCoordinator? = nil
    ) {
        let activityTracker = DisplayActivityTracker()
        self.dataStore = dataStore
        self.immediateCoordinator = immediateCoordinator ?? ImmediateDisplayCoordinator(
            activityTracker: activityTracker
        )
        self.defaultCoordinator = defaultCoordinator ?? DefaultDisplayCoordinator(
            displayInterval: dataStore.double(forKey: Self.displayIntervalKey, defaultValue: 0.0),
            activityTracker: activityTracker
        )
        self.embeddedCoordinator = embeddedCoordinator ?? EmbeddedDisplayCoordinator()
    }

    func displayCoordinator(message: InAppMessage) -> any DisplayCoordinator {
        guard !message.isEmbedded else {
            return embeddedCoordinator
        }
        switch message.displayBehavior {
        case .immediate: return immediateCoordinator
        case .standard: return defaultCoordinator
        case .none: return defaultCoordinator
        }
    }
}
