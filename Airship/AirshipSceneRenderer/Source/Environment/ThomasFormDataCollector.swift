/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ThomasFormDataCollector: ObservableObject {
    private let formState: ThomasFormState?
    private let pagerState: PagerState?

    private var subscriptions: Set<AnyCancellable> = Set()

    init(formState: ThomasFormState? = nil, pagerState: PagerState? = nil) {
        self.formState = formState
        self.pagerState = pagerState

        pagerState?.$currentPageId
            .removeDuplicates()
            // Using this over RunLoop.main as it seems to prevent
            // some unwanted UI jank with form validation enablement
            .receive(on: DispatchQueue.main)
            .sink { [weak formState] _ in
                formState?.dataChanged()
            }
            .store(in: &subscriptions)
    }

    func with(
        formState: ThomasFormState? = nil,
        pagerState: PagerState? = nil
    ) -> ThomasFormDataCollector {
        let newFormState = formState ?? self.formState
        let newPagerState = pagerState ?? self.pagerState

        if newFormState === self.formState, newPagerState === self.pagerState {
            return self
        }

        return .init(
            formState: newFormState,
            pagerState: newPagerState
        )
    }

    func updateField(_ field: ThomasFormField, pageID: String?) {
        formState?.updateField(field) { [weak pagerState] in
            guard let pageID else { return true }
            guard let pagerState else { return false }

            let pageIDs = pagerState.pageItems.map { $0.id }

            // Make sure the page ID is within the current history
            guard
                let current = pagerState.currentPageId,
                let currentIndex = pageIDs.lastIndex(of: current),
                let lastIndex = pageIDs.lastIndex(of: pageID),
                lastIndex <= currentIndex
            else {
                return false
            }
            return true
        }
    }
}


