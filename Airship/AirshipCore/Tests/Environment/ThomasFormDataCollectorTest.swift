/* Copyright Airship and Contributors */

import Testing
import Foundation
import Combine

@testable import AirshipCore

@MainActor
struct ThomasFormDataCollectorTest {
    private let pagerState: PagerState = PagerState(
        identifier: UUID().uuidString,
        branching: nil
    )

    private let formState: ThomasFormState = ThomasFormState(
        identifier: UUID().uuidString,
        formType: .form,
        formResponseType: nil,
        validationMode: .onDemand
    )

    private let pages: [ThomasViewInfo.Pager.Item] = [
        .init(
            identifier: UUID().uuidString,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            branching: nil
        ),
        .init(
            identifier: UUID().uuidString,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            branching: nil
        ),
        .init(
            identifier: UUID().uuidString,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            branching: nil
        )
    ]

    init() {
        pagerState.setPagesAndListenForUpdates(
            pages: self.pages,
            thomasState: .init(formState: self.formState) { _ in },
            swipeDisableSelectors: nil
        )
    }

    @Test("Test collect no page ID.")
    func testCollectNoPageID() async throws {
        let collector = ThomasFormDataCollector(
            formState: self.formState,
            pagerState: self.pagerState
        )

        collector.updateField(.invalidField(identifier: "invalid", input: .score(AirshipJSON.number(1.0))), pageID: nil)
        #expect(self.formState.activeFields["invalid"] != nil)
    }

    @Test("Test collect with page ID.")
    func testCollectWithPageID() async throws {
        let collector = ThomasFormDataCollector(
            formState: self.formState,
            pagerState: self.pagerState
        )

        var activeFields = self.formState.$activeFields.values.makeAsyncIterator()

        collector.updateField(
            .invalidField(
                identifier: "invalid",
                input: .score(AirshipJSON.number(1.0))
            ),
            pageID: pages[1].id
        )

        await #expect(activeFields.next()?["invalid"] == nil)
        self.pagerState.process(request: .next)
        await #expect(activeFields.next()?["invalid"] != nil)
    }
    
}

