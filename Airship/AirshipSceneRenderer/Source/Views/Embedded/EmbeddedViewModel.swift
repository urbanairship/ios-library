/* Copyright Airship and Contributors */

import Combine
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

extension AirshipEmbeddedSelection {
    /// Orders `views` by preference, most preferred first.
    ///
    /// A pure function of `(views, self)` for every case but `.ai` — which resolves through
    /// its fallback here, since the model owns the asynchronous part. That purity is what
    /// lets ``AirshipEmbeddedView`` resolve selection during `body` from the value it was
    /// handed this render, so a changed selection takes effect with nothing to invalidate.
    @MainActor
    func orderedInstanceIDs(
        from views: [PendingEmbedded],
        embeddedID: String,
        tracker: EmbeddedLastDisplayedTracker
    ) -> [String] {
        switch self {
        case .instance(let instanceIDs):
            // An allow-list, not a full ordering: anything not named here is excluded
            // entirely rather than sorted last.
            let pendingIDs = Set(views.map(\.embeddedInfo.instanceID))
            let ordered = instanceIDs.filter { pendingIDs.contains($0) }
            AirshipLogger.trace("Targeted instance order for \(embeddedID): \(ordered)")
            return ordered

        case .comparator(let comparator):
            let ordered = views
                .sorted { comparator($0.embeddedInfo, $1.embeddedInfo) == .orderedAscending }
                .map(\.embeddedInfo.instanceID)
            AirshipLogger.trace("Comparator sorted order for \(embeddedID): \(ordered)")
            return ordered

        case .priority:
            var ordered = views
                .sorted { $0.embeddedInfo.priority < $1.embeddedInfo.priority }
                .map(\.embeddedInfo.instanceID)
            if let lastID = tracker.lastDisplayedID(for: embeddedID),
               let index = ordered.firstIndex(of: lastID) {
                ordered.remove(at: index)
                ordered.insert(lastID, at: 0)
            }
            AirshipLogger.trace("Priority sorted order for \(embeddedID): \(ordered)")
            return ordered

        case .ai(_, let fallback):
            return fallback.asSelection.orderedInstanceIDs(
                from: views,
                embeddedID: embeddedID,
                tracker: tracker
            )
        }
    }
}

@MainActor
final class EmbeddedViewModel: ObservableObject {

    /// The pending set the style renders. Empty only while an `.ai` selection is resolving
    /// with nothing already on screen — so the placeholder blocks until the first ranking lands.
    @Published
    internal private(set) var displayPending: [PendingEmbedded] = []

    /// What the `.ai` selection has decided. Meaningless for any other selection, which the
    /// view resolves itself.
    ///
    /// Deliberately stops short of naming an order in the `.fallback` case: the fallback may
    /// be a closure, and a closure held here would be the one captured when the model was
    /// built. The view applies it instead, against the selection it has this render.
    enum AIOutcome: Equatable {
        /// Settled on this order, most preferred first — either the model's ranking or the
        /// order already on screen, per `allowDisplayInterruptions`.
        case resolved([String])

        /// Still resolving with nothing on screen; block on the placeholder.
        case blocked

        /// No usable AI answer. The view applies the selection's fallback.
        case fallback
    }

    @Published
    internal private(set) var aiOutcome: AIOutcome = .fallback

    private var pending: [PendingEmbedded] = []
    private let embeddedID: String
    private let selection: AirshipEmbeddedSelection

    /// Used only to keep ineligible instances out of the AI prompt. The view applies the
    /// filter it has each render for anything that affects what's displayed, so this copy
    /// being the one captured at init can narrow what was scored but never what is shown.
    private let filterInstances: AirshipEmbeddedFilter?
    private var cancellable: AnyCancellable?
    private var viewManager: any AirshipEmbeddedViewManagerProtocol

    /// Read by the view too, which resolves non-`.ai` selection itself and records what it
    /// ends up displaying — both sides have to agree on which tracker that is.
    let tracker: EmbeddedLastDisplayedTracker
    private var resolveTask: Task<Void, Never>?

    private enum SelectionState {
        case idle
        case resolving
        case ranked([String])
        case fallback
    }
    private var selectionState: SelectionState = .idle
    private var askedIDs: Set<String> = []
    private var knownIDs: Set<String> = []

    /// The order last committed to the screen, most preferred first. Consulted when
    /// `allowDisplayInterruptions` is `false` so a re-rank can only append newly-eligible
    /// arrivals rather than reshuffle what's already there.
    private var committedOrder: [String] = []

    init(
        embeddedID: String,
        selection: AirshipEmbeddedSelection,
        filterInstances: AirshipEmbeddedFilter? = nil,
        manager: any AirshipEmbeddedViewManagerProtocol = AirshipEmbeddedViewManager.shared,
        tracker: EmbeddedLastDisplayedTracker = .shared
    ) {
        self.embeddedID = embeddedID
        self.selection = selection
        self.filterInstances = filterInstances
        self.viewManager = manager
        self.tracker = tracker
        // `[weak self]` rather than passing `onNewViewReceived` directly: the cancellable is
        // stored on self, so a strong capture would be a cycle the model never escapes.
        cancellable = viewManager
            .publisher(embeddedViewID: embeddedID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pending in
                self?.onNewViewReceived(pending)
            }
    }

    private func onNewViewReceived(_ pending: [PendingEmbedded]) {
        let incomingIDs = Set(pending.map(\.embeddedInfo.instanceID))
        let hasNewID = !incomingIDs.isSubset(of: knownIDs)
        let idsChanged = incomingIDs != knownIDs
        self.pending = pending
        self.knownIDs = incomingIDs

        // The fallback is deliberately not read here — see `AIOutcome`.
        guard case .ai(let config, _) = selection else {
            // Everything but `.ai` is a pure function of (pending, selection), so the view
            // resolves it in `body` against the selection it was handed this render. That's
            // what lets a swapped comparator take effect: there's no stored selection here
            // to go stale.
            withAnimation {
                displayPending = pending
            }
            return
        }

        // Only eligible instances are worth scoring: an excluded one can never be shown, so
        // sending it would waste the ask and let it skew the scores of the ones that can.
        let scorable = eligiblePending

        guard scorable.count >= 2 else {
            resolveTask?.cancel()
            selectionState = .fallback
            recomputeAISelection(config: config)
            return
        }

        if hasNewID {
            askAI(incomingIDs: incomingIDs, config: config)
            recomputeAISelection(config: config)
        } else if idsChanged {
            // Something was removed with nothing new arriving — no reason to re-score,
            // but displayPending and the order still need to drop the departed
            // candidate(s). Subsumes a displayed instance itself being dismissed.
            recomputeAISelection(config: config)
        }
    }

    /// Pending instances the filter allows. Everything the AI is asked about comes from
    /// here; what is ultimately displayed is re-filtered by the view.
    private var eligiblePending: [PendingEmbedded] {
        guard let filterInstances else { return pending }
        return pending.filter { filterInstances($0.embeddedInfo) }
    }

    // MARK: - AI selection

    private func askAI(
        incomingIDs: Set<String>,
        config: AirshipEmbeddedSelection.AIConfig
    ) {
        askedIDs = incomingIDs

        guard
            let selector = viewManager.embeddedAISelector,
            selector.isAvailable
        else {
            selectionState = .fallback
            return
        }

        selectionState = .resolving

        let request = EmbeddedAISelectionRequest(
            embeddedID: embeddedID,
            prompt: config.prompt,
            strategy: config.strategy,
            minScoreThreshold: config.minScoreThreshold,
            subjectHints: config.subjectHints,
            candidates: eligiblePending.map(\.embeddedInfo)
        )

        let asked = incomingIDs
        resolveTask?.cancel()
        resolveTask = Task { [weak self] in
            let ranking = await selector.rank(request)
            guard
                !Task.isCancelled,
                let self,
                self.askedIDs == asked
            else {
                return
            }
            self.selectionState = ranking.map { .ranked($0) } ?? .fallback
            self.recomputeAISelection(config: config)
        }
    }

    private func recomputeAISelection(config: AirshipEmbeddedSelection.AIConfig) {

        let pendingIDs = Set(pending.map(\.embeddedInfo.instanceID))

        let order: [String]
        switch selectionState {
        case .ranked(let ranking):
            let ranked = ranking.filter { pendingIDs.contains($0) }
            let stillCommitted = committedOrder.filter { pendingIDs.contains($0) }
            if !config.allowDisplayInterruptions, !stillCommitted.isEmpty {
                // Keep what's already on screen in place; anything newly ranked that wasn't
                // committed yet is new, not a reshuffle, so it's fine to append.
                let arrivals = ranked.filter { !stillCommitted.contains($0) }
                order = stillCommitted + arrivals
            } else {
                order = ranked
            }
        case .resolving, .idle:
            // Keep showing the committed order during a re-ask; empty if nothing is up yet.
            order = committedOrder.filter { pendingIDs.contains($0) }
        case .fallback:
            order = []
        }

        withAnimation {
            if !order.isEmpty {
                committedOrder = order
                displayPending = pending
                aiOutcome = .resolved(order)
            } else if case .resolving = selectionState {
                committedOrder = []
                displayPending = []
                aiOutcome = .blocked
            } else {
                committedOrder = []
                displayPending = pending
                // Which order the fallback names is the view's call, not ours — it has the
                // fallback this render, we have the one we were built with.
                aiOutcome = .fallback
            }
        }
    }
}
