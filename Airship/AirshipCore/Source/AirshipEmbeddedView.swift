/* Copyright Airship and Contributors */

import SwiftUI
import Combine

/**
 * Internal only
 * :nodoc:
 */
public struct AirshipEmbeddedView<PlaceHolder: View>: View {

    @Environment(\.airshipEmbeddedViewStyle)
    private var style

    @StateObject
    private var viewModel: EmbeddedViewModel

    private let placeholder: () -> PlaceHolder
    private let id: String
    private let embeddedSize: AirshipEmbeddedSize?


    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - id: The embedded ID.
    ///   - size: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - placeholder: The place holder block.
    public init(
        id: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder = { EmptyView()}
    ) {
        self.id = id
        self.embeddedSize = embeddedSize
        self.placeholder = placeholder
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(id: id))
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - id: The embedded ID.
    ///   - size: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    public init(
        id: String,
        embeddedSize: AirshipEmbeddedSize? = nil
    ) where PlaceHolder == EmptyView {
        self.id = id
        self.embeddedSize = embeddedSize
        self.placeholder = { EmptyView() }
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(id: id))
    }


    @ViewBuilder
    public var body: some View {
        let configuration = AirshipEmbeddedViewStyleConfiguration(
            views: self.viewModel.pending.map{ pending in
                AirshipLayoutView(
                    view: {
                        EmbeddedView(
                            model: pending.presentation,
                            layout: pending.layout,
                            thomasEnvironment: pending.environment,
                            embeddedSize: embeddedSize
                        )
                    },
                    onDismiss: { pending.environment.dismiss() }
                )
            },
            placeHolder: AnyView(self.placeholder())
        )

        self.style.makeBody(configuration: configuration)
    }
}

private class EmbeddedViewModel: ObservableObject {

    @Published
    var pending: [PendingEmbedded] = []

    private var cancellable: AnyCancellable?
    private var timer: AnyCancellable?
    private var viewManager: AirshipEmbeddedViewManager
    
    init(id: String, manager: AirshipEmbeddedViewManager = AirshipEmbeddedViewManager.shared) {
        self.viewManager = manager
        cancellable = viewManager
            .publisher(embeddedViewID: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: onNewViewReceived)
    }

    private func onNewViewReceived(_ pending: [PendingEmbedded]) {
        withAnimation {
            self.pending = pending
        }
    }
}

/**
 * Internal only
 * :nodoc:
 */
public struct AirshipEmbeddedViewStyleConfiguration {
    public let views: [AirshipLayoutView]
    public let placeHolder: AnyView
}

/**
 * Internal only
 * :nodoc:
 */
public protocol AirshipEmbeddedViewStyle {
    associatedtype Body: View
    typealias Configuration = AirshipEmbeddedViewStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension AirshipEmbeddedViewStyle where Self == DefaultAirshipEmbeddedViewStyle {
    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/**
 * Internal only
 * :nodoc:
 */
public struct DefaultAirshipEmbeddedViewStyle: AirshipEmbeddedViewStyle {
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        if let view = configuration.views.first {
            view
        } else {
            configuration.placeHolder
        }
    }
}

struct AnyAirshipEmbeddedViewStyle: AirshipEmbeddedViewStyle {
    @ViewBuilder
    private let _makeBody: (Configuration) -> AnyView

    init<S: AirshipEmbeddedViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct AirshipEmbeddedViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyAirshipEmbeddedViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipEmbeddedViewStyle: AnyAirshipEmbeddedViewStyle {
        get { self[AirshipEmbeddedViewStyleKey.self] }
        set { self[AirshipEmbeddedViewStyleKey.self] = newValue }
    }
}


extension View {
    public func setAirshipEmbeddedStyle<S>(
        _ style: S
    ) -> some View where S: AirshipEmbeddedViewStyle {
        self.environment(
            \.airshipEmbeddedViewStyle,
            AnyAirshipEmbeddedViewStyle(style: style)
        )
    }
}
