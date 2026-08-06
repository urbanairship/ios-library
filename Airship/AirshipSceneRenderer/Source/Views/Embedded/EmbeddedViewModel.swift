/* Copyright Airship and Contributors */

import Combine
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

@MainActor
final class EmbeddedViewModel: ObservableObject {

    /// The pending set the style renders. Empty only while an `.ai` selection is resolving
    /// with nothing already on screen — so the placeholder blocks until the first ranking lands.
    @Published
    internal private(set) var displayPending: [PendingEmbedded] = []

    /// The instance ID the view model has selected from `displayPending`. Nil means show placeholder.
    @Published
    internal private(set) var selectedInstanceID: String? = nil

    private var pending: [PendingEmbedded] = []
    private let embeddedID: String
    private let selection: AirshipEmbeddedSelection
    private var cancellable: AnyCancellable?
    private var viewManager: any AirshipEmbeddedViewManagerProtocol
    private let tracker: EmbeddedLastDisplayedTracker
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
    private var displayedInstanceID: String?

    init(
        embeddedID: String,
        selection: AirshipEmbeddedSelection,
        manager: any AirshipEmbeddedViewManagerProtocol = AirshipEmbeddedViewManager.shared,
        tracker: EmbeddedLastDisplayedTracker = .shared
    ) {
        self.embeddedID = embeddedID
        self.selection = selection
        self.viewManager = manager
        self.tracker = tracker
        cancellable = viewManager
            .publisher(embeddedViewID: embeddedID)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: onNewViewReceived)
    }

    private func onNewViewReceived(_ pending: [PendingEmbedded]) {
        let incomingIDs = Set(pending.map(\.embeddedInfo.instanceID))
        let hasNewID = !incomingIDs.isSubset(of: knownIDs)
        let idsChanged = incomingIDs != knownIDs
        self.pending = pending
        self.knownIDs = incomingIDs

        guard case .ai(let config, let fallback) = selection else {
            withAnimation {
                displayPending = pending
                updateSelected(selectInstanceID(from: pending))
            }
            return
        }

        guard pending.count >= 2 else {
            resolveTask?.cancel()
            selectionState = .fallback
            recomputeAISelection(config: config, fallback: fallback)
            return
        }

        if hasNewID {
            askAI(incomingIDs: incomingIDs, config: config, fallback: fallback)
            recomputeAISelection(config: config, fallback: fallback)
        } else if idsChanged {
            // Something was removed with nothing new arriving — no reason to re-score,
            // but displayPending and the selection still need to drop the departed
            // candidate. Subsumes the displayed instance itself being dismissed.
            recomputeAISelection(config: config, fallback: fallback)
        }
    }

    private func updateSelected(_ instanceID: String?) {
        selectedInstanceID = instanceID
        if let instanceID {
            tracker.record(embeddedID: embeddedID, instanceID: instanceID)
        }
    }

    private func selectInstanceID(
        from views: [PendingEmbedded],
        overrideSelection: AirshipEmbeddedSelection? = nil
    ) -> String? {
        switch overrideSelection ?? selection {
        case .instance(let instanceID):
            let found = views.contains { $0.embeddedInfo.instanceID == instanceID }
            if found {
                AirshipLogger.trace("Selecting targeted instance view for \(embeddedID): \(instanceID)")
            } else {
                AirshipLogger.trace("No pending view matches targeted instance \(instanceID) for \(embeddedID)")
            }
            return found ? instanceID : nil

        case .comparator(let comparator):
            let view = views.sorted { comparator($0.embeddedInfo, $1.embeddedInfo) == .orderedAscending }.first
            if let view {
                AirshipLogger.trace("Selecting comparator sorted view for \(embeddedID): \(view.embeddedInfo)")
            }
            return view?.embeddedInfo.instanceID

        case .priority:
            if let lastID = tracker.lastDisplayedID(for: embeddedID),
               views.contains(where: { $0.embeddedInfo.instanceID == lastID }) {
                AirshipLogger.trace("Selecting previously displayed view for \(embeddedID): \(lastID)")
                return lastID
            }
            let view = views.sorted { $0.embeddedInfo.priority < $1.embeddedInfo.priority }.first
            if let view {
                AirshipLogger.trace("Selecting priority sorted view for \(embeddedID): \(view.embeddedInfo)")
            }
            return view?.embeddedInfo.instanceID

        case .ai(_, let fallback):
            return selectInstanceID(from: views, overrideSelection: fallback.asSelection)
        }
    }

    // MARK: - AI selection

    private func askAI(
        incomingIDs: Set<String>,
        config: AirshipEmbeddedSelection.AIConfig,
        fallback: AirshipEmbeddedSelection.Fallback
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
            candidates: pending.map(\.embeddedInfo)
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
            self.recomputeAISelection(config: config, fallback: fallback)
        }
    }

    private func recomputeAISelection(
        config: AirshipEmbeddedSelection.AIConfig,
        fallback: AirshipEmbeddedSelection.Fallback
    ) {

        let pendingIDs = Set(pending.map(\.embeddedInfo.instanceID))

        let target: String?
        switch selectionState {
        case .ranked(let ranking):
            if !config.allowDisplayInterruptions,
               let shown = displayedInstanceID, pendingIDs.contains(shown) {
                target = shown
            } else {
                target = ranking.first { pendingIDs.contains($0) }
            }
        case .resolving, .idle:
            // Keep showing what's on screen during a re-ask; block (nil) if nothing is up yet.
            target = displayedInstanceID.flatMap { pendingIDs.contains($0) ? $0 : nil }
        case .fallback:
            target = nil
        }

        withAnimation {
            if let target {
                displayedInstanceID = target
                displayPending = pending
                updateSelected(target)
            } else if case .resolving = selectionState, displayedInstanceID == nil {
                displayedInstanceID = nil
                displayPending = []
                updateSelected(nil)
            } else {
                displayedInstanceID = nil
                displayPending = pending
                updateSelected(selectInstanceID(from: pending, overrideSelection: fallback.asSelection))
            }
        }
    }
}
