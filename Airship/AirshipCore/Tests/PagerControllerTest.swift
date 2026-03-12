/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

struct PagerControllerTest {
    
    @MainActor
    @Test
    func initWithNullState() {
        let controller = AirshipSceneController.PagerController(pagerState: nil)
        #expect(controller.canGoBack == false)
        #expect(controller.canGoNext == false)
        
        #expect(controller.navigate(request: .back) == false)
        #expect(controller.navigate(request: .next) == false)
    }
    
    @MainActor
    @Test
    func controllerDisplaysCorrectStateOnNavigation() {
        let pagerState = PagerState(
            identifier: "test",
            branching: nil
        )
        pagerState.setPagesAndListenForUpdates(
            pages: [
                makePageItem(id: "page-1"),
                makePageItem(id: "page-2")
            ],
            thomasState: .empty,
            swipeDisableSelectors: nil
        )

        let controller = AirshipSceneController.PagerController(pagerState: pagerState)
        #expect(controller.canGoBack == false)
        #expect(controller.canGoNext == true)

        #expect(controller.navigate(request: .back) == false)
        #expect(controller.navigate(request: .next) == true)

        #expect(controller.canGoBack == true)
        #expect(controller.canGoNext == false)

        #expect(controller.navigate(request: .next) == false)
        #expect(controller.navigate(request: .back) == true)

        #expect(controller.canGoBack == false)
        #expect(controller.canGoNext == true)
    }

    @MainActor
    @Test
    func disableTouchDuringNavigation() async throws {
        let sleeper = TestTaskSleeper()
        let sleepUpdates = await sleeper.sleepUpdates
        var iterator = sleepUpdates.makeAsyncIterator()

        let pagerState = PagerState(
            identifier: "test",
            branching: nil,
            taskSleeper: sleeper
        )

        #expect(pagerState.isNavigationInProgress == false)

        pagerState.disableTouchDuringNavigation()
        #expect(pagerState.isNavigationInProgress == true)

        let sleeps = await iterator.next()
        #expect(sleeps?.count == 1)
        #expect(pagerState.isNavigationInProgress == false)
    }
    
    private func makePageItem(id: String) -> ThomasViewInfo.Pager.Item {
        return .init(
            identifier: id,
            view: .emptyView(.init(commonProperties: .init(), properties: .init())),
            displayActions: nil,
            automatedActions: nil,
            accessibilityActions: nil,
            stateActions: nil,
            branching: nil
        )
    }
}

extension ThomasState {
    static var empty: ThomasState {
        return .init(
            formState: .init(
                identifier: "empty",
                formType: .form,
                formResponseType: "none",
                validationMode: .immediate,
            ),
            pagerState: .init(identifier: "", branching: nil),
            onStateChange: { _ in }
        )
    }
}
