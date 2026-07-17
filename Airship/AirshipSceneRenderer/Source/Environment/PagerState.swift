/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

struct PageState: ThomasSerializable {
    var identifier: String
    var delay: Double

    // represent the automated action identifier and it's status (true if it's executed and false if not)
    var automatedActionStatus: [String: Bool] = [:]
    
    init(
        identifier: String,
        delay: Double,
        automatedActions: [String]?
    ) {
        self.identifier = identifier
        self.delay = delay
        
        if let automatedActions = automatedActions {
            automatedActions.forEach { automatedAction in
                self.automatedActionStatus[automatedAction] = false
            }
        }
    }
    
    mutating func markAutomatedActionExecuted(
        _ identifier: String
    ) {
        self.automatedActionStatus[identifier] = true
    }
    
    mutating func resetExecutedActions() {
        automatedActionStatus.keys.forEach { key in
            automatedActionStatus[key] = false
        }
    }
}

enum PageRequest {
    case next
    case back
    case first
    case last
}

struct ThomasPageInfo: Sendable {
    var identifier: String
    var index: Int
    var viewCount: Int
}




@MainActor
final class PagerState: ObservableObject {

    struct NavigationResult: Sendable {
        var fromPage: ThomasPageInfo?
        var toPage: ThomasPageInfo
    }

    var pageIndex: Int {
        pageItems.firstIndex(where: { $0.identifier == currentPageId }) ?? 0
    }

    @Published private(set) var currentPageId: String? {
        didSet {
            guard
                let page = currentPageId,
                page != oldValue
            else {
                return 
            }

            self.pageViewCounts[page] = (self.pageViewCounts[page] ?? 0) + 1
            updateInProgress(pageId: page)
            resetExecutedActions(for: oldValue)
            branchControl?.addToHistoryPage(id: page)
            updateCompleted()
        }
    }
    
    @Published private(set) var pageStates: [PageState] = []
    @Published private(set) var pageItems: [ThomasViewInfo.Pager.Item] = []
    @Published var progress: Double = 0.0
    @Published private(set) var completed: Bool = false
    @Published private(set) var isScrollingDisabled: Bool = false
    @Published private(set) var isNavigationInProgress: Bool = false

    /// Used to pause/resume a story
    @Published var inProgress: Bool = true
    
    private var isManuallyPaused: Bool = false
    private var navigationCooldownTask: Task<Void, Never>?
    private var pageViewCounts: [String: Int] = [:]

    @Published
    var isVoiceOverRunning: Bool = false

    private var mediaReadyState: [MediaKey: Bool] = [:]

    var currentPageState: PageState? {
        get { pageStates.isEmpty ? nil : pageStates[pageIndex] }
        set {
            guard let newValue, !pageStates.isEmpty else { return }
            pageStates[pageIndex] = newValue
        }
    }
    
    private static let navigationCooldownInterval: TimeInterval = 0.3

    let identifier: String
    private let branchControl: BranchControl?
    private var thomasStateSubscription: AnyCancellable? = nil
    private let taskSleeper: any AirshipTaskSleeper
    private var restoredState: Snapshot? = nil

    // Used for reporting
    var reportingPageCount: Int {
        get { branchControl == nil ? pageItems.count : -1 }
    }

    /// Whether the resolved page list is driven by branching, in which case it can
    /// grow or shrink as layout state changes.
    var isBranching: Bool {
        branchControl != nil
    }

    init(
        identifier: String,
        branching: ThomasPagerControllerBranching?,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
    ) {
        self.identifier = identifier
        self.taskSleeper = taskSleeper
        
        if let branching {
            branchControl = BranchControl(completionChecker: branching)
        } else {
            branchControl = nil
        }
        
        if let branchControl {
            // Branch re-evaluation runs on every state change and usually resolves the
            // same path — dedupe so identical results don't re-publish (and re-layout
            // the pager) mid scroll animation.
            branchControl.$pages
                .removeDuplicates()
                .map { pages in
                    pages.map { $0.toPageState() }
                }
                .assign(to: &$pageStates)

            branchControl.$pages.removeDuplicates().assign(to: &$pageItems)

            branchControl.$isComplete.removeDuplicates().assign(to: &$completed)
        }
    }
    
    func setPagesAndListenForUpdates(
        pages: [ThomasViewInfo.Pager.Item],
        thomasState: ThomasState,
        swipeDisableSelectors: [ThomasViewInfo.Pager.DisableSwipeSelector]?
    ) {
        let pagesChanged = pages != self.pageItems

        if let branchControl {
            branchControl.configureAndAttachTo(
                pages: pages,
                thomasState: thomasState
            )
        } else {
            self.pageStates = restoredState?.pageStates ?? pages.map({ $0.toPageState() })
            self.pageItems = pages
        }

        thomasStateSubscription?.cancel()
        if let selectors = swipeDisableSelectors {
            thomasStateSubscription = thomasState.$state
                .receive(on: DispatchQueue.main)
                .sink { @MainActor [weak self] newState in
                    self?.reEvaluateScrollability(state: newState, selectors: selectors)
                }
        }

        if let restored = restoredState {
            // pager uses scrollview + lazystack. in this configuration it could ignore scrolling to position
            // until the stack is initialized and loaded. schedule a page navigation task
            restored.currentPageId.flatMap(self.schedulePageNavigation)
            self.progress = restored.progress

            self.restoredState = nil
        } else if self.currentPageId == nil || (branchControl == nil && pagesChanged) {
            // `pagesChanged` compares the authored list against the resolved one, which
            // never match while branching — resetting on it would snap a re-attached
            // branching pager (e.g. after rotation) back to the first page.
            self.currentPageId = pageItems.first?.identifier
        }
    }

    func pause() {
        self.isManuallyPaused = true
        if let currentPageId {
            updateInProgress(pageId: currentPageId)
        }
    }

    func togglePause() {
        if self.isManuallyPaused {
            resume()
        } else {
            pause()
        }
    }


    func resume() {
        self.isManuallyPaused = false
        if let currentPageId {
            updateInProgress(pageId: currentPageId)
        }
    }
    
    var isFirstPage: Bool {
        return pageIndex == 0
    }
    
    var isLastPage: Bool {
        return pageIndex == pageItems.count - 1
    }
    
    var canGoBack: Bool {
        return pageIndex > 0
    }

    var canGoForward: Bool {
        return pageIndex < pageItems.count - 1
    }

    @discardableResult
    func navigateToPage(id: String) -> NavigationResult?  {
        guard
            self.pageItems.contains(where: { $0.identifier == id }),
            id != self.currentPageId
        else {
            return nil
        }

        let fromPage: ThomasPageInfo? = if let currentPageId {
            self.pageInfo(pageIdentifier: currentPageId)
        } else {
            nil
        }

        let toPage = self.pageInfo(pageIdentifier: id)

        branchControl?.clearHistoryAfter(id: id)
        self.progress = 0.0
        self.currentPageId = id
        return NavigationResult(fromPage: fromPage, toPage: toPage)
    }

    func pageInfo(pageIdentifier: String) -> ThomasPageInfo {
        return ThomasPageInfo(
            identifier: pageIdentifier,
            index: self.pageItems.firstIndex(where: { item in
                item.identifier == pageIdentifier
            }) ?? -1,
            viewCount: self.pageViewCounts[pageIdentifier] ?? 0
        )
    }

    func pageInfo(index: Int) -> ThomasPageInfo {
        let pageIdentifier = self.pageItems[index].identifier
        return ThomasPageInfo(
            identifier: pageIdentifier,
            index: index,
            viewCount: self.pageViewCounts[pageIdentifier] ?? 0
        )
    }
    
    private var pageNavigationTask: Task<Void, Never>? = nil
    func schedulePageNavigation(_ pageId: String) {
        pageNavigationTask?.cancel()
        
        let scrollDelay = 0.05 // 50ms
        
        //try to navigate to the page id in the usual way
        self.currentPageId = pageId
        
        pageNavigationTask = Task { @MainActor [weak self] in
            guard let pageIds = self?.pageItems.map(\.identifier) else {
                return
            }
            
            // wait for the navigation animation
            try? await self?.taskSleeper.sleep(timeInterval: 0.2)
            //cooperative cancel task if the usual navigation worked
            guard !Task.isCancelled else { return }
            
            // once we failed to navigate to the target page, iterate thru all pager pages and navigate to the next
            // until we reach the target page. that solves navigation with lazy stacks when we might not have the target
            // screen rendered
            // ignore task cancellation
            for item in pageIds {
                await Task.yield()
                self?.currentPageId = item
                if item == pageId { break }
                try? await self?.taskSleeper.sleep(timeInterval: scrollDelay)
            }
        }
    }
    
    func confirmNavigation() {
        pageNavigationTask?.cancel()
    }

    @discardableResult
    func process(request: PageRequest) -> NavigationResult? {
        guard !pageItems.isEmpty else { return nil }
        let id = pageItems[nextIndexNoBranching(request: request)].identifier
        guard
            let result = self.navigateToPage(id: id)
        else {
            return nil
        }

        branchControl?.onPageRequest(request)
        return result
    }
    
    private func reEvaluateScrollability(
        state: AirshipJSON,
        selectors: [ThomasViewInfo.Pager.DisableSwipeSelector]
    ) {
        let selector = selectors.first(where: { $0.predicate?.evaluate(json: state) ?? true })

        let disabled = switch(selector?.direction) {
        case .horizontal: true
        case .none: false
        }
        if isScrollingDisabled != disabled {
            isScrollingDisabled = disabled
        }
    }
    
    private func resetExecutedActions(for pageId: String?) {
        guard
            let pageId,
            let index = pageStates.firstIndex(where: { $0.identifier == pageId })
        else {
            return
        }
        
        pageStates[index].resetExecutedActions()
    }
    
    /// Starts a programmatic navigation: locks out scrollPosition writebacks and
    /// touch (`isNavigationInProgress`) until `endNavigation()` is called when the
    /// scroll animation completes. A stale writeback mid-animation would otherwise
    /// read as a user swipe back to the outgoing page. The failsafe here releases
    /// the lock if the caller's animation completion never fires.
    ///
    /// WORKAROUND: SwiftUI's scrollPosition(id:) has a race condition where rapid
    /// touch during a scroll animation desyncs scrollPosition from the actual
    /// position — this lock also gates hit testing while navigating.
    func beginNavigation() {
        self.isNavigationInProgress = true
        self.navigationCooldownTask?.cancel()
        self.navigationCooldownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await taskSleeper.sleep(timeInterval: 2.0)
            guard !Task.isCancelled else { return }
            self.navigationCooldownTask = nil
            self.isNavigationInProgress = false
        }
    }

    /// Ends a navigation started with `beginNavigation()`: keeps the lock through a
    /// short tail cooldown — the scroll view can emit trailing writebacks just after
    /// the animation logically completes — then releases it.
    func endNavigation() {
        self.isNavigationInProgress = true
        self.navigationCooldownTask?.cancel()
        self.navigationCooldownTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await taskSleeper.sleep(timeInterval: Self.navigationCooldownInterval)
            guard !Task.isCancelled else { return }
            self.navigationCooldownTask = nil
            self.isNavigationInProgress = false
        }
    }
    
    private func nextIndexNoBranching(request: PageRequest) -> Int {
        return switch request {
        case .next: min(pageIndex + 1, pageItems.count - 1)
        case .back: max(pageIndex - 1, 0)
        case .first: 0
        case .last: max(pageItems.count - 1, 0)
        }
    }
    
    private func updateCompleted() {
        if branchControl != nil || completed {
            return
        }
        
        completed = pageIndex == (pageItems.count - 1)
    }

    func registerMedia(pageId: String, id: UUID) {
        let key = MediaKey(pageId: pageId, id: id)
        guard mediaReadyState[key] == nil else { return }
        mediaReadyState[key] = false
        updateInProgress(pageId: pageId)
    }

    func setMediaReady(pageId: String, id: UUID, isReady: Bool) {
        let key = MediaKey(pageId: pageId, id: id)
        mediaReadyState[key] = isReady
        updateInProgress(pageId: pageId)
    }

    func markAutomatedActionExecuted(_ identifier: String) {
        self.currentPageState?.markAutomatedActionExecuted(identifier)
    }

    private func updateInProgress(pageId: String) {
        let isMediaReady = !mediaReadyState.contains(where: { key, isReady in
            key.pageId == pageId && isReady == false
        })

        let update = isMediaReady && !isManuallyPaused && !isVoiceOverRunning
        if self.inProgress != update {
            self.inProgress = update
        }
    }

    struct MediaKey: Hashable, Equatable {
        let pageId: String
        let id: UUID
    }
}

@MainActor
private final class BranchControl: Sendable {
    private let completionChecker: ThomasPagerControllerBranching
    
    private var allPages: [ThomasViewInfo.Pager.Item] = []
    
    @Published private(set) var pages: [ThomasViewInfo.Pager.Item] = []
    @Published private(set) var isComplete: Bool = false

    private var thomasState: ThomasState?
    private var history: [ThomasViewInfo.Pager.Item] = []
    private var subscriptions: Set<AnyCancellable> = []
    
    init(completionChecker: ThomasPagerControllerBranching) {
        self.completionChecker = completionChecker
    }

    private var payload: AirshipJSON {
        return self.thomasState?.state ?? .null
    }

    func configureAndAttachTo(
        pages: [ThomasViewInfo.Pager.Item],
        thomasState: ThomasState
    ) {
        detach()

        self.thomasState = thomasState

        allPages = pages

        thomasState.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &subscriptions)

        updateState()
    }
    
    func detach() {
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
    }

    private func updateState() {
        self.reEvaluatePath()
        self.evaluateCompletion()
    }
    
    
    func onPageRequest(_ request: PageRequest) {
        self.updateState()
        
        switch request {
        case .next, .back, .last: break
        case .first: history.removeAll()
        }
    }
    
    func clearHistoryAfter(id: String) {
        guard let index = history.firstIndex(where: { $0.identifier == id }) else {
            return
        }
        
        history.removeSubrange((index + 1)...)
    }
    
    func addToHistoryPage(id: String) {
        guard
            let page = allPages.first(where: { $0.identifier == id }),
            !history.contains(page)
        else {
            return
        }
        
        history.append(page)
    }

    private func reEvaluatePath() {
        if history.isEmpty, !allPages.isEmpty {
            history = [allPages[0]]
        }
        
        var historyCopy = history
        guard let current = historyCopy.popLast() else {
            return
        }

        let resolved = historyCopy + buildPathFrom(page: current, payload: payload)
        if resolved != pages {
            pages = resolved
        }
    }
    
    private func buildPathFrom(
        page: ThomasViewInfo.Pager.Item,
        payload: AirshipJSON
    ) -> [ThomasViewInfo.Pager.Item] {
        
        guard var pageIndex = allPages.firstIndex(of: page) else {
            return []
        }
        
        var result: [ThomasViewInfo.Pager.Item] = []
        
        while(pageIndex >= 0 && pageIndex < allPages.count) {
            let current = allPages[pageIndex]
            
            if result.contains(current) {
                AirshipLogger.warn("Trying to add a duplicate \(current)")
                break
            }
            
            result.append(current)
            
            guard
                let branching = current.branching,
                let nextPage = branching.nextPageId(json: payload),
                let nextPageIndex = allPages.firstIndex(where: { $0.identifier == nextPage })
            else {
                break
            }
            
            pageIndex = nextPageIndex
        }
        
        return result
    }
    
    private func evaluateCompletion() {
        guard !isComplete else { return }

        let result = completionChecker.completions.contains {
            $0.predicate?.evaluate(json: payload) != false
        }

        guard result else { return }

        performCompletionOutcomes()
        self.isComplete = true
    }

    private func performCompletionOutcomes() {
        guard let thomasState else { return }
        
        let outcomes = completionChecker.completions
            .filter { $0.predicate?.evaluate(json: payload) != false }
            .compactMap { $0.outcomes ?? $0.stateActions?.map(\.asOutcome) }
            .flatMap { $0 }
        
        Task {
            await thomasState.process(outcomes: outcomes)
        }
    }
}

fileprivate extension ThomasPageBranching {
    func nextPageId(json: AirshipJSON) -> String? {
        return nextPage?
            .first(where: { selector in
                selector.predicate?.evaluate(json: json) != false
            })?
            .pageId
    }
}

fileprivate extension ThomasViewInfo.Pager.Item {
    func toPageState() -> PageState {
        return PageState(
            identifier: identifier,
            delay: automatedActions?.earliestNavigationAction?.delay ?? 0.0,
            automatedActions: automatedActions?.compactMap { automatedAction in
                automatedAction.identifier
            }
        )
    }
}

//MARK: - ThomasStateProvider
extension PagerState: ThomasStateProvider {
    typealias SnapshotType = Snapshot
    
    struct Snapshot: Codable, Equatable {
        let pageStates: [PageState]
        let currentPageId: String?
        let progress: Double
    }
    
    var updates: AnyPublisher<any Codable, Never> {
        return Publishers
            .CombineLatest3($pageStates, $currentPageId, $progress)
            .map(Snapshot.init)
            .removeDuplicates()
            .map(\.self)
            .eraseToAnyPublisher()
    }
    
    func persistentStateSnapshot() -> SnapshotType {
        Snapshot(
            pageStates: self.pageStates,
            currentPageId: self.currentPageId,
            progress: self.progress
        )
    }
    
    func restorePersistentState(_ state: Snapshot) {
        self.restoredState = state
    }
}
