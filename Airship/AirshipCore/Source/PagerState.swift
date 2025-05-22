/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

struct PageState: Sendable {
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
}

struct ThomasPageInfo: Sendable {
    var identifier: String
    var index: Int
    var viewCount: Int
}




@MainActor
class PagerState: ObservableObject {

    struct NavigationResult: Sendable {
        var fromPage: ThomasPageInfo?
        var toPage: ThomasPageInfo
    }

    @Published private(set) var pageIndex: Int = 0

    @Published private(set) var currentPageId: String? {
        didSet {
            guard
                let page = currentPageId,
                page != oldValue,
                let index = pageItems.firstIndex(where: { $0.identifier == page })
            else {
                return
            }

            self.pageViewCounts[page] = (self.pageViewCounts[page] ?? 0) + 1
            pageIndex = index
            updateInProgress(pageId: page)
            resetExecutedActions(for: oldValue)
            branchControl?.addToHistoryPage(id: page)
            updateCompleted()
            updateScrollControl()
        }
    }
    
    @Published private(set) var pageStates: [PageState] = []
    @Published private(set) var pageItems: [ThomasViewInfo.Pager.Item] = []
    @Published var progress: Double = 0.0
    @Published private(set) var completed: Bool = false
    @Published private(set) var isScrollingDisabled = false

    /// Used to pause/resume a story
    @Published var inProgress: Bool = true
    
    private var isManuallyPaused = false
    private var clearPagingRequestTask: Task<Void, Never>?
    private var pageViewCounts: [String: Int] = [:]

    @Published
    var isVoiceOverRunning = false

    private var mediaReadyState: [MediaKey: Bool] = [:]

    var currentPageState: PageState {
        get { pageStates[pageIndex] }
        set { pageStates[pageIndex] = newValue }
    }
    
    let identifier: String
    private let branchControl: BranchControl?
    private var thomasStateSubscription: AnyCancellable? = nil
    
    //determin if the scrollview should be disabled based on `ThomasViewInfo.Pager.DisableSwipeSelector`
    private var isScrollSelectorDisabled: Bool = false
    
    //used for reporting
    var reportingPageCount: Int {
        get { branchControl == nil ? pageItems.count : -1 }
    }

    init(identifier: String, branching: ThomasPagerControllerBranching?) {
        self.identifier = identifier
        
        if let branching {
            branchControl = BranchControl(completionChecker: branching)
        } else {
            branchControl = nil
        }
        
        if let branchControl {
            branchControl.$pages
                .map { pages in
                    pages.map { $0.toPageState() }
                }
                .assign(to: &$pageStates)
            
            branchControl.$pages.assign(to: &$pageItems)
            branchControl.$isComplete.assign(to: &$completed)
        }
    }
    
    func setPagesAndListenForUpdates(
        pages: [ThomasViewInfo.Pager.Item],
        thomasState: ThomasState,
        swipeDisableSelectors: [ThomasViewInfo.Pager.DisableSwipeSelector]?
    ) {
        if let branchControl {
            branchControl.configureAndAttachTo(
                pages: pages,
                thomasState: thomasState
            )
        } else {
            self.pageStates = pages.map({ $0.toPageState() })
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

        self.currentPageId = pageItems.first?.identifier
    }

    func pause() {
        self.isManuallyPaused = true
        if let currentPageId {
            updateInProgress(pageId: currentPageId)
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
        return pageIndex > 0 && !isScrollingDisabled
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
                item.identifier == identifier
            }) ?? -1,
            viewCount: self.pageViewCounts[identifier] ?? 0
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

    @discardableResult
    func process(request: PageRequest) -> NavigationResult? {
        let id = pageItems[nextIndexNoBranching(request: request)].identifier
        guard
            let result = self.navigateToPage(id: id)
        else {
            return nil
        }

        branchControl?.onPageRequest(request)
        if #available(iOS 16.0, *) {
            fixTouchDuringNavigationIssue()
        } else {
            updateScrollControl()
        }

        return result
    }
    
    private func reEvaluateScrollability(
        state: AirshipJSON,
        selectors: [ThomasViewInfo.Pager.DisableSwipeSelector]
    ) {
        let selector = selectors.first(where: { $0.predicate?.evaluate(json: state) ?? true })
        
        switch(selector?.direction) {
        case .horizontal:
            isScrollSelectorDisabled = true
        case .none:
            isScrollSelectorDisabled = false
        }
         
        self.updateScrollControl()
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
    
    private func updateScrollControl() {
        self.isScrollingDisabled = isScrollSelectorDisabled
    }
    
    @available(iOS 16.0, *)
    private func fixTouchDuringNavigationIssue() {
        // This workarounds an issue that I found with scrollPosition(id:)
        // where if you animate the scrollPosition and touch fast enough
        // to interrupt the scroll behavior, the scrollPosition will
        // think its on the other page, but in reality its not. To prevent
        // this, we are disabling touch while we have a `self.pagerState.pageRequest`
        // and enabling it after 250 ms. And yes, I tried using the completion handler
        // on the animation but it was being called immediately no matter what I
        // did, probably due to some config on the scroll view.
        self.isScrollingDisabled = true
        self.clearPagingRequestTask?.cancel()
        self.clearPagingRequestTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            self.updateScrollControl()
        }
    }
    
    private func nextIndexNoBranching(request: PageRequest) -> Int {
        return switch request {
        case .next:
            min(pageIndex + 1, pageItems.count - 1)
        case .back:
            max(pageIndex - 1, 0)
        case .first:
            0
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
    }

    func setMediaReady(pageId: String, id: UUID, isReady: Bool) {
        let key = MediaKey(pageId: pageId, id: id)
        mediaReadyState[key] = true
        updateInProgress(pageId: pageId)
    }

    func markAutomatedActionExecuted(_ identifier: String) {
        self.currentPageState.markAutomatedActionExecuted(identifier)
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
private class BranchControl: Sendable {
    let completionChecker: ThomasPagerControllerBranching
    
    private var allPages: [ThomasViewInfo.Pager.Item] = []
    
    @Published private(set) var pages: [ThomasViewInfo.Pager.Item] = []
    @Published private(set) var isComplete: Bool = false

    private var thomasState: ThomasState?
    private var history: [ThomasViewInfo.Pager.Item] = []
    private var subscriptions: Set<AnyCancellable> = []
    
    init(completionChecker: ThomasPagerControllerBranching) {
        self.completionChecker = completionChecker
    }

    var payload: AirshipJSON {
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
        case .next, .back: break
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
        
        pages = historyCopy + buildPathFrom(page: current, payload: payload)
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
        
        var result = false
        for indicator in completionChecker.completions {
            if indicator.predicate?.evaluate(json: payload) != false {
                result = true
                break
            }
        }
        
        if result, result != isComplete {
            performCompletionStateActions()
        }
        
        self.isComplete = result
    }
    
    private func performCompletionStateActions() {
        guard let thomasState else { return }
        let actions = completionChecker.completions
            .filter { $0.predicate?.evaluate(json: payload) != false }
            .compactMap { $0.stateActions }
            .flatMap { $0 }

        thomasState.processStateActions(actions)
    }
}

fileprivate extension ThomasPageBranching {
    func nextPageId(json: AirshipJSON) -> String? {
        return nextPage?
            .first(where: { selector in
                let isMatched = selector.predicate?.evaluate(json: json) != false
                return isMatched
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
