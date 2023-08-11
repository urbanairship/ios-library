/* Copyright Airship and Contributors */

import Foundation

struct PageState {
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

class PagerState: ObservableObject {
    @Published var pageIndex: Int = 0
    @Published var pages: [PageState] = []
    @Published var progress: Double = 0.0
    @Published var completed: Bool = false
    
    /// Used to pause/resume a story
    var inProgress: Bool = true
    var currentPage: PageState {
        get { pages[pageIndex] }
        set { pages[pageIndex] = newValue }
    }
    
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }
    
    func isLastPage() -> Bool {
        return pageIndex == (pages.count - 1)
    }

    func pause() {
        self.inProgress = false
    }

    func resume() {
        self.inProgress = true
    }
    
    func resetProgress() {
        self.progress = 0.0
    }
    
    func markAutomatedActionExecuted(_ identifier: String) {
        self.currentPage.markAutomatedActionExecuted(identifier)
    }
}
