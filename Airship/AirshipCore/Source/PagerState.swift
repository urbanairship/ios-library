/* Copyright Airship and Contributors */

import Foundation

struct PageState {
    var identifier: String
    var delay: Double
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
}
