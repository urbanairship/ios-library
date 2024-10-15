/* Copyright Airship and Contributors */

public import SwiftUI
import Combine

/// Airship embedded view - a scene that can be embedded in an app and managed remotely
public struct AirshipEmbeddedView<PlaceHolder: View>: View {

    @Environment(\.airshipEmbeddedViewStyle)
    private var style

    @StateObject
    private var viewModel: EmbeddedViewModel

    private let placeholder: () -> PlaceHolder
    private let embeddedID: String
    private let embeddedSize: AirshipEmbeddedSize?

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - size: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - placeholder: The place holder block.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder = { EmptyView()}
    ) {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.placeholder = placeholder
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID))
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - size: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil
    ) where PlaceHolder == EmptyView {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.placeholder = { EmptyView() }
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID))
    }

    public var body: some View {
        let pending = viewModel.pending

        let configuration = AirshipEmbeddedViewStyleConfiguration(
            embeddedID: embeddedID,
            views: pending.map{ pending in
                AirshipEmbeddedContentView(
                    embeddedInfo: pending.embeddedInfo,
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

        return self.style.makeBody(configuration: configuration)
    }
}


@MainActor
private class EmbeddedViewModel: ObservableObject {

    @Published
    var pending: [PendingEmbedded] = []

    private var cancellable: AnyCancellable?
    private var timer: AnyCancellable?
    private var viewManager: AirshipEmbeddedViewManager
    
    init(embeddedID: String, manager: AirshipEmbeddedViewManager = AirshipEmbeddedViewManager.shared) {
        self.viewManager = manager
        cancellable = viewManager
            .publisher(embeddedViewID: embeddedID)
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
public struct AirshipEmbeddedContentView : View, Identifiable  {
    public let embeddedInfo: AirshipEmbeddedInfo

    public var id: String {
        embeddedInfo.instanceID
    }

    private let view: () -> EmbeddedView
    private let onDismiss: () -> Void

    internal init(
        embeddedInfo: AirshipEmbeddedInfo,
        view: @escaping () -> EmbeddedView,
        onDismiss: @escaping () -> Void
    ) {
        self.embeddedInfo = embeddedInfo
        self.view = view
        self.onDismiss = onDismiss
    }

    public func dismiss() {
        self.onDismiss()
    }

    @ViewBuilder
    public var body: some View {
        view().onAppear {
            EmbeddedViewSelector.shared.onViewDisplayed(embeddedInfo)
        }
        .id(embeddedInfo.instanceID)
    }
}

/// Style configuration for customizing an Airship embedded view
public struct AirshipEmbeddedViewStyleConfiguration {
    public let embeddedID: String
    public let views: [AirshipEmbeddedContentView]
    public let placeHolder: AnyView
}

/// Protocol for customizing an Airship embedded view with a style
public protocol AirshipEmbeddedViewStyle {
    associatedtype Body: View
    typealias Configuration = AirshipEmbeddedViewStyleConfiguration
    @preconcurrency @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension AirshipEmbeddedViewStyle where Self == DefaultAirshipEmbeddedViewStyle {
    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// Default style for embedded views
public struct DefaultAirshipEmbeddedViewStyle: AirshipEmbeddedViewStyle {

    @MainActor
    private func nextView(configuration: Configuration) -> AirshipEmbeddedContentView? {
        return EmbeddedViewSelector.shared.selectView(
            embeddedID: configuration.embeddedID,
            views: configuration.views
       )
    }

    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        if let view = nextView(configuration: configuration) {
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
    /// Setter for applying a style to an Airship embedded view
    public func setAirshipEmbeddedStyle<S>(
        _ style: S
    ) -> some View where S: AirshipEmbeddedViewStyle {
        self.environment(
            \.airshipEmbeddedViewStyle,
            AnyAirshipEmbeddedViewStyle(style: style)
        )
    }
}
