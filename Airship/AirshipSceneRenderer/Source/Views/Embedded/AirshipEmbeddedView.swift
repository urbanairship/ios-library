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

    /// Let the on-device model pick which pending instance to display.
    ///
    /// The placeholder is shown while the model decides (the selection blocks until it
    /// resolves). If the model is unavailable or has no opinion, `fallback` is used instead.
    case ai(config: AIConfig, fallback: Fallback)

    /// A non-AI selection strategy used as the fallback for ``AirshipEmbeddedSelection/ai(config:fallback:)``.
    public enum Fallback: Sendable {
        /// Display by priority ordering, preferring the last displayed instance.
        case priority

        /// Sort the available contents with a comparator and display the first.
        case comparator(AirshipEmbeddedComparator)

        /// Display a specific pending instance by its ``AirshipEmbeddedInfo/instanceID``.
        case instance(String)

        var asSelection: AirshipEmbeddedSelection {
            switch self {
            case .priority: return .priority
            case .comparator(let c): return .comparator(c)
            case .instance(let id): return .instance(id)
            }
        }
    }

    /// Configuration for ``AirshipEmbeddedSelection/ai(config:fallback:)``.
    public struct AIConfig: Sendable {

        /// Defines how AI evaluation scores are combined with candidate priorities.
        public enum Strategy: Sendable, Hashable, Equatable {
            /// AI score takes primary precedence; candidate priority breaks ties among candidates with equal scores.
            case scoreThenPriority

            /// Candidate priority takes primary precedence; AI score breaks ties among candidates with equal priority.
            case priorityThenScore
        }

        /// Instruction describing how to choose among the pending instances.
        ///
        /// The model scores each candidate 1–10 based on this prompt and the user's context,
        /// then displays the highest-scoring instance. Write the prompt as a relevance
        /// description: e.g. `"Show content that matches the user's interests."` or
        /// `"Prioritize time-sensitive offers over evergreen content."`
        public let prompt: String

        /// Strategy for ordering candidates using AI scores and priority.
        public let strategy: Strategy

        /// Minimum score the top-ranked candidate must achieve for the AI result to be accepted.
        ///
        /// The model scores each candidate from 1 (poor match) to 10 (direct match). If the
        /// winning candidate's score is below this threshold the AI result is discarded and the
        /// `fallback` selection is used instead. `nil` always accepts the AI result.
        public let minScoreThreshold: Int?

        /// Whether a change in the pending set may re-run the model and swap the displayed
        /// instance. When `false`, once an instance is chosen it keeps displaying (even as
        /// other instances come and go) until it's dismissed.
        public let allowDisplayInterruptions: Bool

        /// Extra key-value data carried on the subject handed to the app's context provider
        /// (as `subject.hints`). Not added to the prompt by the renderer.
        public let subjectHints: [String: String]

        public init(
            prompt: String,
            strategy: Strategy = .scoreThenPriority,
            minScoreThreshold: Int? = nil,
            allowDisplayInterruptions: Bool = false,
            subjectHints: [String: String] = [:]
        ) {
            self.prompt = prompt
            self.strategy = strategy
            self.minScoreThreshold = minScoreThreshold
            self.allowDisplayInterruptions = allowDisplayInterruptions
            self.subjectHints = subjectHints
        }
    }
}

extension AirshipEmbeddedSelection {
    /// Convenience factory for ``AirshipEmbeddedSelection/ai(config:fallback:)`` that avoids constructing ``AIConfig`` directly.
    public static func ai(
        prompt: String,
        strategy: AIConfig.Strategy = .scoreThenPriority,
        minScoreThreshold: Int? = nil,
        allowDisplayInterruptions: Bool = false,
        subjectHints: [String: String] = [:],
        fallback: Fallback = .priority
    ) -> Self {
        .ai(
            config: AIConfig(
                prompt: prompt,
                strategy: strategy,
                minScoreThreshold: minScoreThreshold,
                allowDisplayInterruptions: allowDisplayInterruptions,
                subjectHints: subjectHints
            ),
            fallback: fallback
        )
    }
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
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID, selection: selection))
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
        self._viewModel = StateObject(wrappedValue: EmbeddedViewModel(embeddedID: embeddedID, selection: selection))
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
        let pendingConfig = viewModel.displayPending.map { item in
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
        }

        let configuration = AirshipEmbeddedViewStyleConfiguration(
            embeddedID: embeddedID,
            pending: pendingConfig,
            placeHolder: AnyView(self.placeholder()),
            selection: selection,
            selected: pendingConfig.first { $0.id == viewModel.selectedInstanceID }
        )

        return self.style.makeBody(configuration: configuration)
    }
}

/// - Note: For internal use only. :nodoc:
public struct AirshipEmbeddedContentView: View, Identifiable {
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
        view()
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

    /// How the view model selected content. Custom styles can use `selected` for the
    /// pre-computed result, or inspect this and `pending` to apply their own ordering.
    public let selection: AirshipEmbeddedSelection

    /// The pre-computed selected content. `nil` means show the placeholder.
    public let selected: Pending?

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
        selection: AirshipEmbeddedSelection = .priority,
        selected: Pending? = nil
    ) {
        self.embeddedID = embeddedID
        self.pending = pending
        self.placeHolder = placeHolder
        self.selection = selection
        self.selected = selected
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
    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        if let view = configuration.selected?.content {
            view
                .transition(.opacity)
        } else {
            configuration.placeHolder
                .transition(.opacity)
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
