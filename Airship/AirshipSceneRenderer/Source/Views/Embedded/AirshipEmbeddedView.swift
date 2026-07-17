/* Copyright Airship and Contributors */

public import SwiftUI
import Combine

/// A closure used to sort the available embedded contents for an embedded ID.
///
/// Return `.orderedAscending` to display `lhs` before `rhs`. When set, this replaces the default priority ordering.
public typealias AirshipEmbeddedComparator = @Sendable (_ lhs: AirshipEmbeddedInfo, _ rhs: AirshipEmbeddedInfo) -> ComparisonResult

/// Describes how an ``AirshipEmbeddedView`` chooses which pending embedded content
/// to display when more than one instance is available for an embedded ID.
public enum AirshipEmbeddedSelection: Sendable {

    /// Display by priority ordering, preferring the last displayed instance.
    ///
    /// This is the default behavior.
    case priority

    /// Sort the available contents with a comparator and display the first.
    ///
    /// Return `.orderedAscending` from the comparator to display `lhs` before `rhs`.
    case comparator(AirshipEmbeddedComparator)

    /// Display a specific pending instance by its ``AirshipEmbeddedInfo/instanceID``,
    /// bypassing ordering.
    ///
    /// The placeholder is shown until that instance is pending.
    case instance(String)
}

/// Airship embedded view - a scene that can be embedded in an app and managed remotely
public struct AirshipEmbeddedView<PlaceHolder: View>: View {

    @Environment(\.airshipEmbeddedViewStyle)
    private var style

    @StateObject
    private var viewModel: EmbeddedViewModel

    private let placeholder: () -> PlaceHolder
    private let embeddedID: String
    private let embeddedSize: AirshipEmbeddedSize?
    private let selection: AirshipEmbeddedSelection

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content to display when more than one is available. Defaults to `.priority`.
    ///   - placeholder: The place holder block.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder
    ) {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.placeholder = placeholder
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID))
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content to display when more than one is available. Defaults to `.priority`.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority
    ) where PlaceHolder == EmptyView {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.placeholder = { EmptyView() }
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID))
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - comparator: Optional comparator used to sort the available embedded contents. Defaults to priority ordering.
    ///   - placeholder: The place holder block.
    @available(*, deprecated, message: "Use init(embeddedID:embeddedSize:selection:placeholder:) with .comparator(...)")
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        comparator: AirshipEmbeddedComparator?,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder
    ) {
        self.init(
            embeddedID: embeddedID,
            embeddedSize: embeddedSize,
            selection: comparator.map { .comparator($0) } ?? .priority,
            placeholder: placeholder
        )
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - comparator: Optional comparator used to sort the available embedded contents. Defaults to priority ordering.
    @available(*, deprecated, message: "Use init(embeddedID:embeddedSize:selection:) with .comparator(...)")
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        comparator: AirshipEmbeddedComparator?
    ) where PlaceHolder == EmptyView {
        self.init(
            embeddedID: embeddedID,
            embeddedSize: embeddedSize,
            selection: comparator.map { .comparator($0) } ?? .priority
        )
    }

    public var body: some View {
        let pending = viewModel.pending

        let configuration = AirshipEmbeddedViewStyleConfiguration(
            embeddedID: embeddedID,
            pending: pending.map { item in
                AirshipEmbeddedViewStyleConfiguration.Pending(
                    content: AirshipEmbeddedContentView(
                        embeddedInfo: item.embeddedInfo,
                        view: {
                            EmbeddedView(
                                presentation: item.presentation,
                                layout: item.layout,
                                thomasEnvironment: item.environment,
                                embeddedSize: embeddedSize
                            )
                        },
                        dismissHandle: item.dismissHandle
                    ),
                    onDismiss: { item.dismissHandle.dismiss() }
                )
            },
            placeHolder: AnyView(self.placeholder()),
            selection: selection
        )

        return self.style.makeBody(configuration: configuration)
    }
}


@MainActor
private final class EmbeddedViewModel: ObservableObject {

    @Published
    fileprivate var pending: [PendingEmbedded] = []

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

/// - Note: For internal use only. :nodoc:
public struct AirshipEmbeddedContentView : View, Identifiable  {
    public let embeddedInfo: AirshipEmbeddedInfo

    nonisolated public var id: String {
        embeddedInfo.instanceID
    }

    private let view: () -> EmbeddedView
    private let dismissHandle: ThomasDismissHandle

    internal init(
        embeddedInfo: AirshipEmbeddedInfo,
        view: @escaping () -> EmbeddedView,
        dismissHandle: ThomasDismissHandle
    ) {
        self.embeddedInfo = embeddedInfo
        self.view = view
        self.dismissHandle = dismissHandle
    }

    public func dismiss() {
        self.dismissHandle.dismiss()
    }

    @ViewBuilder
    public var body: some View {
        view().onAppear {
            EmbeddedViewSelector.shared.onViewDisplayed(embeddedInfo)
        }
        .id(embeddedInfo.instanceID)
    }
}

public struct AirshipEmbeddedViewStyleConfiguration {
    public struct Pending: Identifiable {
        public let content: AirshipEmbeddedContentView
        public let onDismiss: @MainActor () -> Void
        public var id: String { content.id }
    }

    public let embeddedID: String
    public let pending: [Pending]
    public let placeHolder: AnyView

    /// How to select which pending content to display when more than one is available.
    public let selection: AirshipEmbeddedSelection

    /// Optional comparator used to sort the available embedded contents.
    @available(*, deprecated, message: "Use `selection`.")
    public var comparator: AirshipEmbeddedComparator? {
        if case .comparator(let comparator) = selection {
            return comparator
        }
        return nil
    }

    /// Deprecated: Use `pending` instead.
    @available(*, deprecated, message: "Use `pending` which includes dismissal logic per-view.")
    public var views: [AirshipEmbeddedContentView] {
        return pending.map { $0.content }
    }

    internal init(
        embeddedID: String,
        pending: [Pending],
        placeHolder: AnyView,
        selection: AirshipEmbeddedSelection = .priority
    ) {
        self.embeddedID = embeddedID
        self.pending = pending
        self.placeHolder = placeHolder
        self.selection = selection
    }
}

/// Protocol for customizing an Airship embedded view with a style
public protocol AirshipEmbeddedViewStyle: Sendable {
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
            views: configuration.pending.map { $0.content },
            selection: configuration.selection
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
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: AirshipEmbeddedViewStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct AirshipEmbeddedViewStyleKey: EnvironmentKey {
    static let defaultValue: AnyAirshipEmbeddedViewStyle = AnyAirshipEmbeddedViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    fileprivate var airshipEmbeddedViewStyle: AnyAirshipEmbeddedViewStyle {
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
