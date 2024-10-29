/* Copyright Airship and Contributors */

import Foundation

struct PageState: Sendable {
    var identifier: String
    var delay: Double
    // represent the automated action identifier and it's status (true if it's executed and false if not)
    var automatedActionStatus: [String: Bool] = [:]
    
    init(identifier: String,
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
}

enum PageRequest {
    case next
    case back
    case first
}

@MainActor
class PagerState: ObservableObject {
    @Published private(set) var pageIndex: Int = 0 {
        didSet {
            updateInProgress()
        }
    }

    @Published var pageRequest: PageRequest?
    @Published var pages: [PageState] = []
    @Published var progress: Double = 0.0
    @Published var completed: Bool = false
    
    /// Used to pause/resume a story
    @Published var inProgress: Bool = true
    
    private var isManuallyPaused = false

    private var mediaReadyState: [MediaKey: Bool] = [:]

    var currentPage: PageState {
        get { pages[pageIndex] }
        set { pages[pageIndex] = newValue }
    }
    
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }

    func pause() {
        self.isManuallyPaused = true
        updateInProgress()
    }

    func resume() {
        self.isManuallyPaused = false
        updateInProgress()
    }

    func setPageIndex(_ pageIndex: Int) {
        guard
            pageIndex >= 0,
            pageIndex != self.pageIndex,
            pageIndex < self.pages.count
        else {
            return
        }

        self.progress = 0.0
        self.pageIndex = pageIndex
    }

    var isFirstPage: Bool {
        return pageIndex == 0
    }
    
    var isLastPage: Bool {
        return pageIndex == (pages.count - 1)
    }

    var nextPageIndex: Int {
        min(pageIndex + 1, pages.count - 1)
    }

    var previousPageIndex: Int {
        max(pageIndex - 1, 0)
    }

    func registerMedia(pageIndex: Int, id: UUID) {
        let key = MediaKey(pageIndex: pageIndex, id: id)
        guard mediaReadyState[key] == nil else { return }
        mediaReadyState[key] = false
    }

    func setMediaReady(pageIndex: Int, id: UUID, isReady: Bool) {
        let key = MediaKey(pageIndex: pageIndex, id: id)
        mediaReadyState[key] = true
        updateInProgress()
    }

    func markAutomatedActionExecuted(_ identifier: String) {
        self.currentPage.markAutomatedActionExecuted(identifier)
    }

    private func updateInProgress() {
        let isMediaReady = !mediaReadyState.contains(where: { key, isReady in
            key.pageIndex == pageIndex && isReady == false
        })

        let update = isMediaReady && !isManuallyPaused
        if self.inProgress != update {
            self.inProgress = update
        }
    }

    struct MediaKey: Hashable, Equatable {
        let pageIndex: Int
        let id: UUID
    }
}


