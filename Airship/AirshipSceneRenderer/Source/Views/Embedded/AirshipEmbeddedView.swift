/* Copyright Airship and Contributors */

public import SwiftUI
import Combine

/// A closure used to sort the available embedded contents for an embedded ID.
///
/// Return `.orderedAscending` to display `lhs` before `rhs`. When set, this replaces the default priority ordering.
public typealias AirshipEmbeddedComparator = @Sendable (_ lhs: AirshipEmbeddedInfo, _ rhs: AirshipEmbeddedInfo) -> ComparisonResult

/// A closure deciding whether a pending embedded instance is eligible to be displayed.
///
/// Return `false` to drop it. Eligibility, not ordering — which one of the survivors is
/// displayed is ``AirshipEmbeddedSelection``'s job.
public typealias AirshipEmbeddedFilter = @MainActor (_ info: AirshipEmbeddedInfo) -> Bool

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
    ///
    /// Handing the view a comparator that sorts differently re-sorts what's on screen; the
    /// comparator is applied on each render rather than captured when the view first
    /// appeared.
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
        /// The model scores each candidate 1–10 against this prompt, what each candidate's
        /// layout says about itself (`content_description`), and any user context an app
        /// context provider supplies; the highest-scoring instance is displayed. A context
        /// provider is optional — a prompt that ranks on the content alone
        /// (`"Prioritize time-sensitive offers over evergreen content."`) works without one,
        /// while a prompt about the person (`"Show content that matches the user's
        /// interests."`) only differentiates if a provider is registered for
        /// `AirshipAI.EmbeddedSelection.usage`.
        ///
        /// Selection is skipped, and `fallback` used, when no candidate carries anything to
        /// rank on — no `content_description` and no extras.
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
    /// Identifies the part of a selection the view model is built around, used to key the
    /// content view so a change it can't otherwise see rebuilds that model.
    ///
    /// Only an `.ai` config contributes anything: it drives an asynchronous state machine
    /// the model owns, so a reworded prompt or a new threshold has to re-ask rather than
    /// keep a ranking made under the old config.
    ///
    /// Everything else — including an `.ai` selection's *fallback* — is resolved during
    /// `body` from the value handed in that render, so it needs no identity here. That's
    /// what lets a swapped comparator closure take effect despite closures having nothing
    /// to compare.
    var changeKey: String {
        switch self {
        case .priority, .comparator, .instance:
            return "sync"
        case .ai(let config, _):
            return "ai:\(config.changeKey)"
        }
    }
}

extension AirshipEmbeddedSelection.AIConfig {
    /// Every field that changes what the model is asked, so a reworded prompt or a new
    /// threshold re-asks rather than keeping a ranking made under the old config.
    var changeKey: String {
        let hints = subjectHints
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return [
            prompt,
            "\(strategy)",
            minScoreThreshold.map(String.init) ?? "-",
            "\(allowDisplayInterruptions)",
            hints,
        ].joined(separator: "|")
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

    private let placeholder: () -> PlaceHolder
    private let embeddedID: String
    private let embeddedSize: AirshipEmbeddedSize?
    private let selection: AirshipEmbeddedSelection
    private let filterInstances: AirshipEmbeddedFilter?

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content to display when more than one is available. Defaults to `.priority`.
    ///   - filterInstances: Optional filter deciding which pending instances are eligible. Applied before `selection`, so a filtered-out instance is never displayed even when `selection` targets it. Defaults to no filtering.
    ///   - placeholder: The place holder block.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority,
        filterInstances: AirshipEmbeddedFilter? = nil,
        @ViewBuilder placeholder: @escaping () -> PlaceHolder
    ) {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.filterInstances = filterInstances
        self.placeholder = placeholder
    }

    /// Creates a new AirshipEmbeddedView.
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID.
    ///   - embeddedSize: The embedded size info. This is needed in a scroll view to determine proper percent based sizing.
    ///   - selection: How to select which pending content to display when more than one is available. Defaults to `.priority`.
    ///   - filterInstances: Optional filter deciding which pending instances are eligible. Applied before `selection`, so a filtered-out instance is never displayed even when `selection` targets it. Defaults to no filtering.
    public init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize? = nil,
        selection: AirshipEmbeddedSelection = .priority,
        filterInstances: AirshipEmbeddedFilter? = nil
    ) where PlaceHolder == EmptyView {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.filterInstances = filterInstances
        self.placeholder = { EmptyView() }
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
        // The content view owns the `@StateObject`, and `.id` gives it an identity derived
        // from the parameters that model is built from. SwiftUI keys state by structural
        // position, not by property values, so without this a new `embeddedID` or
        // `selection` would reach the struct and never reach the model.
        AirshipEmbeddedContent(
            embeddedID: embeddedID,
            embeddedSize: embeddedSize,
            selection: selection,
            filterInstances: filterInstances,
            placeholder: placeholder
        )
        .id("\(embeddedID)\u{1}\(selection.changeKey)")
    }
}

/// Holds the state for one `(embeddedID, selection)` pair. Re-created by `.id` when either
/// changes — see ``AirshipEmbeddedView/body``.
private struct AirshipEmbeddedContent<PlaceHolder: View>: View {

    @Environment(\.airshipEmbeddedViewStyle)
    private var style

    @StateObject
    private var viewModel: EmbeddedViewModel

    private let placeholder: () -> PlaceHolder
    private let embeddedID: String
    private let embeddedSize: AirshipEmbeddedSize?
    private let selection: AirshipEmbeddedSelection
    private let filterInstances: AirshipEmbeddedFilter?

    init(
        embeddedID: String,
        embeddedSize: AirshipEmbeddedSize?,
        selection: AirshipEmbeddedSelection,
        filterInstances: AirshipEmbeddedFilter?,
        placeholder: @escaping () -> PlaceHolder
    ) {
        self.embeddedID = embeddedID
        self.embeddedSize = embeddedSize
        self.selection = selection
        self.filterInstances = filterInstances
        self.placeholder = placeholder
        self._viewModel = StateObject(
            wrappedValue: EmbeddedViewModel(
                embeddedID: embeddedID,
                selection: selection,
                filterInstances: filterInstances
            )
        )
    }

    /// The instances eligible to be displayed this render.
    ///
    /// Applied here rather than only in the model so a changed filter takes effect at once:
    /// the model holds the closure it was built with (it needs one to decide what to send
    /// the AI), and a closure can't be keyed. That copy can only affect which candidates
    /// were scored, never what is shown.
    private var eligiblePending: [PendingEmbedded] {
        guard let filterInstances else { return viewModel.displayPending }
        return viewModel.displayPending.filter { filterInstances($0.embeddedInfo) }
    }

    var body: some View {
        let eligiblePending = self.eligiblePending
        let pendingConfig = eligiblePending.map { item in
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

        let selectedInstanceID = self.selectedInstanceID

        let configuration = AirshipEmbeddedViewStyleConfiguration(
            embeddedID: embeddedID,
            pending: pendingConfig,
            placeHolder: AnyView(self.placeholder()),
            selection: selection,
            selected: pendingConfig.first { $0.id == selectedInstanceID }
        )

        return self.style.makeBody(configuration: configuration)
            // Recording is a side effect, so it can't live in `body` — and this is the
            // truer moment for it anyway: the tracker is "last displayed", and until now it
            // recorded what was selected.
            .task(id: selectedInstanceID) {
                guard let selectedInstanceID else { return }
                viewModel.tracker.record(
                    embeddedID: embeddedID,
                    instanceID: selectedInstanceID
                )
            }
    }

    /// Resolved fresh each render from the selection this render was handed, rather than the
    /// one the view model was built with — so a changed `.instance`, comparator, or ordering
    /// takes effect without the model knowing anything changed.
    ///
    /// `.ai` is only partly the model's: it decides *whether* it has an answer, since that
    /// arrives asynchronously, but when it doesn't, naming the fallback instance happens
    /// here. A fallback comparator would otherwise be the one captured at init, stale in
    /// exactly the way the rest of this avoids.
    private var selectedInstanceID: String? {
        let eligible = self.eligiblePending

        guard case .ai(_, let fallback) = selection else {
            return selection.selectInstanceID(
                from: eligible,
                embeddedID: embeddedID,
                tracker: viewModel.tracker
            )
        }

        switch viewModel.aiOutcome {
        case .resolved(let instanceID):
            // The model may have scored under an older filter, or the filter may have
            // changed since. The current one is the one that decides.
            guard eligible.contains(where: { $0.embeddedInfo.instanceID == instanceID }) else {
                return fallback.asSelection.selectInstanceID(
                    from: eligible,
                    embeddedID: embeddedID,
                    tracker: viewModel.tracker
                )
            }
            return instanceID
        case .blocked:
            return nil
        case .fallback:
            return fallback.asSelection.selectInstanceID(
                from: eligible,
                embeddedID: embeddedID,
                tracker: viewModel.tracker
            )
        }
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
