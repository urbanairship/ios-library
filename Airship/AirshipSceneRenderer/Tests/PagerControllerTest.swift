/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
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
    func navigationLockHoldsUntilEndNavigationTailCooldown() async throws {
        let sleeper = TestTaskSleeper()

        let pagerState = PagerState(
            identifier: "test",
            branching: nil,
            taskSleeper: sleeper
        )

        #expect(pagerState.isNavigationInProgress == false)

        pagerState.beginNavigation()
        #expect(pagerState.isNavigationInProgress == true)

        // Ending navigation keeps the lock through the tail cooldown.
        pagerState.endNavigation()
        #expect(pagerState.isNavigationInProgress == true)

        await sleeper.waitForSleep(0.3)
        // yield to let the PagerState task resume and set isNavigationInProgress = false
        await Task.yield()
        #expect(pagerState.isNavigationInProgress == false)
    }

    @MainActor
    @Test
    func navigationLockFailsafeReleasesWithoutEndNavigation() async throws {
        let sleeper = TestTaskSleeper()

        let pagerState = PagerState(
            identifier: "test",
            branching: nil,
            taskSleeper: sleeper
        )

        pagerState.beginNavigation()
        #expect(pagerState.isNavigationInProgress == true)

        await sleeper.waitForSleep(2.0)
        // yield to let the failsafe task resume and release the lock
        await Task.yield()
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
            displayOutcomes: nil,
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
