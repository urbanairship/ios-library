/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference center content phase
public enum PreferenceCenterContentPhase: Sendable {
    /// The view is loading
    case loading
    /// The view failed to load the config
    case error(any Error)
    /// The view is loaded with the state
    case loaded(PreferenceCenterState)
}

/// The core view for the Airship Preference Center.
/// This view is responsible for loading and displaying the preference center content. For a navigation controller, see `PreferenceCenterView`.
@MainActor
public struct PreferenceCenterContent: View {

    @StateObject
    private var loader: PreferenceCenterContentLoader = PreferenceCenterContentLoader()

    @State
    private var initialLoadCalled = false

    @State
    private var namedUser: String?

    @Environment(\.airshipPreferenceCenterStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    private let preferenceCenterID: String
    private let onLoad: (@Sendable (String) async -> PreferenceCenterContentPhase)?
    private let onPhaseChange: ((PreferenceCenterContentPhase) -> Void)?

    /// The default constructor
    /// - Parameters:
    ///   - preferenceCenterID: The preference center ID
    ///   - onLoad: An optional load block to load the view phase
    ///   - onPhaseChange: A callback when the phase changed
    public init(
        preferenceCenterID: String,
        onLoad: (@Sendable (String) async -> PreferenceCenterContentPhase)? = nil,
        onPhaseChange: ((PreferenceCenterContentPhase) -> Void)? = nil
    ) {
        self.preferenceCenterID = preferenceCenterID
        self.onLoad = onLoad
        self.onPhaseChange = onPhaseChange
    }

    @ViewBuilder
    public var body: some View {
        let phase = self.loader.phase

        let refresh: @MainActor @Sendable () -> Void = { @MainActor in
            self.loader.load(
                preferenceCenterID: preferenceCenterID,
                onLoad: onLoad
            )
        }

        let configuration = PreferenceCenterContentStyleConfiguration(
            phase: phase,
            preferenceCenterTheme: self.preferenceCenterTheme,
            colorScheme: self.colorScheme,
            refresh: refresh
        )

        style.makeBody(configuration: configuration)
            .onReceive(makeNamedUserIDPublisher()) { identifier in
                if (self.namedUser != identifier) {
                    self.namedUser = identifier
                    refresh()
                }
            }
            .onReceive(self.loader.$phase) {
                self.onPhaseChange?($0)

                if !self.initialLoadCalled {
                    refresh()
                    self.initialLoadCalled = true
                }
            }
    }

    private func makeNamedUserIDPublisher() -> AnyPublisher<String?, Never> {
        guard Airship.isFlying else {
            return Just(nil).eraseToAnyPublisher()
        }

        return Airship.contact.namedUserIDPublisher
            .receive(on: RunLoop.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
}
