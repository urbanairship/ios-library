/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

// MARK: - Test Doubles

@MainActor
final class TestThomasDelegate: ThomasDelegate {
    var visibilityChanges: [(isVisible: Bool, isForegrounded: Bool)] = []
    var reportedEvents: [ThomasReportingEvent] = []
    var dismissals: [Bool] = []
    var stateChanges: [AirshipJSON] = []

    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {
        visibilityChanges.append((isVisible, isForegrounded))
    }

    func onReportingEvent(_ event: ThomasReportingEvent) {
        reportedEvents.append(event)
    }

    func onDismissed(cancel: Bool) {
        dismissals.append(cancel)
    }

    func onStateChanged(_ state: AirshipJSON) {
        stateChanges.append(state)
    }
}

@MainActor
final class TestTimer: AirshipTimerProtocol {
    var time: TimeInterval = 0
    var isStarted: Bool = false
    var startCount: Int = 0
    var stopCount: Int = 0

    func start() {
        isStarted = true
        startCount += 1
    }

    func stop() {
        isStarted = false
        stopCount += 1
    }
}

// MARK: - Tests

@MainActor
struct ThomasEnvironmentTest {

    // MARK: - Helper Methods

    private func makeEnvironment(
        delegate: TestThomasDelegate? = nil,
        timer: TestTimer? = nil,
        pagerTracker: ThomasPagerTracker? = nil,
        extensions: ThomasExtensions? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> (ThomasEnvironment, TestThomasDelegate, TestTimer) {
        let testDelegate = delegate ?? TestThomasDelegate()
        let testTimer = timer ?? TestTimer()

        let env = ThomasEnvironment(
            delegate: testDelegate,
            extensions: extensions,
            pagerTracker: pagerTracker,
            timer: testTimer,
            onDismiss: onDismiss
        )

        return (env, testDelegate, testTimer)
    }

    private func setupAirship() -> (TestContact, TestChannel) {
        let testAirship = TestAirshipInstance()
        let testContact = TestContact()
        let testChannel = TestChannel()
        let date = UATestDate()

        testContact.attributeEditor = AttributesEditor(date: date) { _ in }
        testChannel.attributeEditor = AttributesEditor(date: date) { _ in }

        testAirship.components = [testContact, testChannel]
        testAirship.makeShared()

        return (testContact, testChannel)
    }

    // MARK: - Initialization Tests

    @Test
    func testCustomDependencies() {
        let customDelegate = TestThomasDelegate()
        let customTimer = TestTimer()
        let customTracker = ThomasPagerTracker()
        var dismissCalled = false

        let (env, delegate, timer) = makeEnvironment(
            delegate: customDelegate,
            timer: customTimer,
            pagerTracker: customTracker,
            onDismiss: { dismissCalled = true }
        )

        // Verify custom dependencies are used
        #expect(delegate === customDelegate)
        #expect(timer === customTimer)

        // Verify onDismiss callback
        env.dismiss()
        #expect(dismissCalled)
    }

    // MARK: - Visibility & Timer Tests

    @Test
    func testVisibilityStartsTimer() {
        let (env, delegate, timer) = makeEnvironment()

        env.onVisibilityChanged(isVisible: true, isForegrounded: true)

        #expect(timer.isStarted)
        #expect(timer.startCount == 1)
        #expect(delegate.visibilityChanges.count == 1)
        #expect(delegate.visibilityChanges[0].isVisible == true)
        #expect(delegate.visibilityChanges[0].isForegrounded == true)
    }

    @Test
    func testVisibilityStopsTimerWhenNotVisible() {
        let (env, delegate, timer) = makeEnvironment()

        // Start timer first
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)

        // Stop when not visible
        env.onVisibilityChanged(isVisible: false, isForegrounded: true)

        #expect(!timer.isStarted)
        #expect(timer.stopCount == 1)
        #expect(delegate.visibilityChanges.count == 2)
        #expect(delegate.visibilityChanges[1].isVisible == false)
    }

    @Test
    func testVisibilityStopsTimerWhenBackgrounded() {
        let (env, delegate, timer) = makeEnvironment()

        // Start timer first
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)

        // Stop when backgrounded
        env.onVisibilityChanged(isVisible: true, isForegrounded: false)

        #expect(!timer.isStarted)
        #expect(timer.stopCount == 1)
        #expect(delegate.visibilityChanges.count == 2)
        #expect(delegate.visibilityChanges[1].isForegrounded == false)
    }

    @Test
    func testVisibilityTimerRestart() {
        let (env, _, timer) = makeEnvironment()

        // Start
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)
        #expect(timer.startCount == 1)

        // Background
        env.onVisibilityChanged(isVisible: true, isForegrounded: false)
        #expect(!timer.isStarted)

        // Foreground again - should restart
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)
        #expect(timer.startCount == 2)
    }

    // MARK: - State Management Tests

    @Test
    func testRetrieveStateCreatesNewState() {
        let (env, _, _) = makeEnvironment()

        let state = env.retrieveState(identifier: "test") {
            ThomasState.MutableState()
        }

        #expect(state != nil)
    }

    @Test
    func testRetrieveStateReturnsSameInstance() {
        let (env, _, _) = makeEnvironment()

        let state1 = env.retrieveState(identifier: "test") {
            ThomasState.MutableState()
        }

        let state2 = env.retrieveState(identifier: "test") {
            ThomasState.MutableState()
        }

        #expect(state1 === state2)
    }

    @Test
    func testRetrieveStateIsolatesDifferentIdentifiers() {
        let (env, _, _) = makeEnvironment()

        let state1 = env.retrieveState(identifier: "test1") {
            ThomasState.MutableState()
        }

        let state2 = env.retrieveState(identifier: "test2") {
            ThomasState.MutableState()
        }

        #expect(state1 !== state2)
    }

    // MARK: - Form Event Tests

    @Test
    func testFormDisplayed() {
        let (env, delegate, _) = makeEnvironment()

        let formState = ThomasFormState(
            identifier: "test-form",
            formType: .form,
            formResponseType: "response-type",
            validationMode: .immediate
        )

        env.formDisplayed(formState, layoutState: .empty)

        #expect(delegate.reportedEvents.count == 1)

        if case .formDisplay(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-form")
            #expect(event.formType == "form")
        } else {
            Issue.record("Expected formDisplay event")
        }
    }

    @Test
    func testFormDisplayedWithNPSType() {
        let (env, delegate, _) = makeEnvironment()

        let formState = ThomasFormState(
            identifier: "nps-form",
            formType: .nps("score-id"),
            formResponseType: "response-type",
            validationMode: .immediate
        )

        env.formDisplayed(formState, layoutState: .empty)

        #expect(delegate.reportedEvents.count == 1)

        if case .formDisplay(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "nps-form")
            #expect(event.formType == "nps")
        } else {
            Issue.record("Expected formDisplay event with NPS type")
        }
    }

    @Test
    func testSubmitFormReportsEvent() {
        let (env, delegate, _) = makeEnvironment()

        let result = ThomasFormResult(
            identifier: "test-form",
            formData: .object([:])
        )

        env.submitForm(
            result: result,
            channels: [],
            attributes: [],
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .formResult = delegate.reportedEvents[0] {
            // Success
        } else {
            Issue.record("Expected formResult event")
        }
    }

    @Test
    func testSubmitFormCallsAirshipWithEmailAndSMS() {
        let (testContact, testChannel) = setupAirship()
        defer { TestAirshipInstance.clearShared() }

        let (env, delegate, _) = makeEnvironment()

        let result = ThomasFormResult(
            identifier: "test-form",
            formData: .object([:])
        )

        let channels: [ThomasFormField.Channel] = [
            .email("test@example.com", ThomasEmailRegistrationOptions.optIn()),
            .sms("15035551234", ThomasSMSRegistrationOptions.optIn(senderID: "12345"))
        ]

        let attributes: [ThomasFormField.Attribute] = [
            ThomasFormField.Attribute(
                attributeName: ThomasAttributeName(channel: "test_attr", contact: "contact_attr"),
                attributeValue: .string("test_value")
            )
        ]

        env.submitForm(
            result: result,
            channels: channels,
            attributes: attributes,
            layoutState: .empty
        )

        // Verify event was reported
        #expect(delegate.reportedEvents.count == 1)

        // TestContact and TestChannel provide no-ops for registerEmail/SMS/editAttributes
        // but the fact that we didn't crash proves the Airship singleton was accessible
    }

    // MARK: - Button Event Tests

    @Test
    func testButtonTapped() {
        let (env, delegate, _) = makeEnvironment()

        let metadata = AirshipJSON.object(["key": .string("value")])

        env.buttonTapped(
            buttonIdentifier: "test-button",
            reportingMetadata: metadata,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .buttonTap(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-button")
            #expect(event.reportingMetadata == metadata)
        } else {
            Issue.record("Expected buttonTap event")
        }
    }

    // MARK: - Pager Event Tests

    @Test
    func testPageViewed() {
        let (env, delegate, timer) = makeEnvironment()
        timer.time = 5.0

        let pagerState = PagerState(
            identifier: "test-pager",
            branching: nil
        )

        let pageInfo = ThomasPageInfo(
            identifier: "page-1",
            index: 0,
            viewCount: 1
        )

        env.pageViewed(
            pagerState: pagerState,
            pageInfo: pageInfo,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .pageView(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-pager")
            #expect(event.pageIdentifier == "page-1")
            #expect(event.pageIndex == 0)
        } else {
            Issue.record("Expected pageView event")
        }
    }

    @Test
    func testPagerCompleted() {
        let (env, delegate, _) = makeEnvironment()

        let pagerState = PagerState(
            identifier: "test-pager",
            branching: nil
        )

        env.pagerCompleted(pagerState: pagerState, layoutState: .empty)

        #expect(delegate.reportedEvents.count == 1)

        if case .pagerCompleted(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-pager")
        } else {
            Issue.record("Expected pagerCompleted event")
        }
    }

    @Test
    func testPageSwiped() {
        let (env, delegate, _) = makeEnvironment()

        let pagerState = PagerState(
            identifier: "test-pager",
            branching: nil
        )

        let fromPage = ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1)
        let toPage = ThomasPageInfo(identifier: "page-1", index: 1, viewCount: 1)

        env.pageSwiped(
            pagerState: pagerState,
            from: fromPage,
            to: toPage,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .pageSwipe(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-pager")
            #expect(event.fromPageIdentifier == "page-0")
            #expect(event.toPageIdentifier == "page-1")
            #expect(event.fromPageIndex == 0)
            #expect(event.toPageIndex == 1)
        } else {
            Issue.record("Expected pageSwipe event")
        }
    }

    @Test
    func testPageGestureWithIdentifier() {
        let (env, delegate, _) = makeEnvironment()

        env.pageGesture(
            identifier: "test-gesture",
            reportingMetadata: nil,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .gesture(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-gesture")
        } else {
            Issue.record("Expected gesture event")
        }
    }

    @Test
    func testPageGestureWithoutIdentifier() {
        let (env, delegate, _) = makeEnvironment()

        env.pageGesture(
            identifier: nil,
            reportingMetadata: nil,
            layoutState: .empty
        )

        // Should not report event when identifier is nil
        #expect(delegate.reportedEvents.isEmpty)
    }

    @Test
    func testPageAutomatedWithIdentifier() {
        let (env, delegate, _) = makeEnvironment()

        env.pageAutomated(
            identifier: "test-action",
            reportingMetadata: nil,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .pageAction(let event, _) = delegate.reportedEvents[0] {
            #expect(event.identifier == "test-action")
        } else {
            Issue.record("Expected pageAction event")
        }
    }

    @Test
    func testPageAutomatedWithoutIdentifier() {
        let (env, delegate, _) = makeEnvironment()

        env.pageAutomated(
            identifier: nil,
            reportingMetadata: nil,
            layoutState: .empty
        )

        // Should not report event when identifier is nil
        #expect(delegate.reportedEvents.isEmpty)
    }

    @Test
    func testMultiplePageViewsWithHistory() {
        let tracker = ThomasPagerTracker()
        let (env, delegate, timer) = makeEnvironment(pagerTracker: tracker)

        let pagerState = PagerState(
            identifier: "test-pager",
            branching: nil
        )

        // View multiple pages in sequence
        let page1 = ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1)
        timer.time = 0
        env.pageViewed(pagerState: pagerState, pageInfo: page1, layoutState: .empty)

        let page2 = ThomasPageInfo(identifier: "page-1", index: 1, viewCount: 1)
        timer.time = 5.0
        env.pageViewed(pagerState: pagerState, pageInfo: page2, layoutState: .empty)

        let page3 = ThomasPageInfo(identifier: "page-2", index: 2, viewCount: 1)
        timer.time = 10.0
        env.pageViewed(pagerState: pagerState, pageInfo: page3, layoutState: .empty)

        // Verify all page views were reported
        #expect(delegate.reportedEvents.count == 3)

        // Verify each event has progressively more history in context
        if case .pageView(_, let context1) = delegate.reportedEvents[0] {
            #expect(context1.pager?.pageHistory.count == 0)
        }

        if case .pageView(_, let context2) = delegate.reportedEvents[1] {
            #expect(context2.pager?.pageHistory.count == 1)
            #expect(context2.pager?.pageHistory[0].identifier == "page-0")
        }

        if case .pageView(_, let context3) = delegate.reportedEvents[2] {
            #expect(context3.pager?.pageHistory.count == 2)
            #expect(context3.pager?.pageHistory[0].identifier == "page-0")
            #expect(context3.pager?.pageHistory[1].identifier == "page-1")
        }
    }

    // MARK: - Dismiss Tests

    @Test
    func testDismissWithButtonVerifyEventDetails() {
        let (env, delegate, timer) = makeEnvironment()
        timer.time = 10.5

        env.dismiss(
            buttonIdentifier: "close-btn",
            buttonDescription: "Close Button",
            cancel: true,
            layoutState: .empty
        )

        #expect(env.isDismissed)
        #expect(!timer.isStarted)
        #expect(timer.stopCount == 1)
        #expect(delegate.reportedEvents.count == 1)

        if case .dismiss(let dismissType, let displayTime, _) = delegate.reportedEvents[0] {
            // Verify it's buttonTapped type
            if case .buttonTapped(let id, let desc) = dismissType {
                #expect(id == "close-btn")
                #expect(desc == "Close Button")
            } else {
                Issue.record("Expected buttonTapped dismiss type")
            }
            // Verify display time
            #expect(displayTime == 10.5)
        } else {
            Issue.record("Expected dismiss event")
        }

        #expect(delegate.dismissals[0] == true)
    }

    @Test
    func testDismissUserDismissedEventType() {
        let (env, delegate, timer) = makeEnvironment()
        timer.time = 7.3

        env.dismiss(cancel: false, layoutState: .empty)

        #expect(delegate.reportedEvents.count == 1)

        if case .dismiss(let dismissType, let displayTime, _) = delegate.reportedEvents[0] {
            // Verify it's userDismissed type
            if case .userDismissed = dismissType {
                // Success
            } else {
                Issue.record("Expected userDismissed dismiss type")
            }
            // Verify display time
            #expect(displayTime == 7.3)
        } else {
            Issue.record("Expected dismiss event")
        }
    }

    @Test
    func testTimedOutEventType() {
        let (env, delegate, timer) = makeEnvironment()
        timer.time = 30.0

        env.timedOut(layoutState: .empty)

        #expect(delegate.reportedEvents.count == 1)

        if case .dismiss(let dismissType, let displayTime, _) = delegate.reportedEvents[0] {
            // Verify it's timedOut type
            if case .timedOut = dismissType {
                // Success
            } else {
                Issue.record("Expected timedOut dismiss type")
            }
            // Verify display time
            #expect(displayTime == 30.0)
        } else {
            Issue.record("Expected dismiss event")
        }
    }

    @Test
    func testRepeatedDismissIsIdempotent() {
        let (env, delegate, timer) = makeEnvironment()

        env.dismiss()
        env.dismiss()
        env.dismiss()

        // Should only dismiss once
        #expect(env.isDismissed)
        #expect(timer.stopCount == 1)
        #expect(delegate.dismissals.count == 1)
    }

    @Test
    func testOnDismissCallbackCalledOnce() {
        var callCount = 0
        let (env, _, _) = makeEnvironment(onDismiss: {
            callCount += 1
        })

        env.dismiss()
        env.dismiss()

        #expect(callCount == 1)
    }

    @Test
    func testDismissFromWithinCallback() {
        var env: ThomasEnvironment!
        var recursiveCallAttempted = false

        let delegate = TestThomasDelegate()
        let timer = TestTimer()
        timer.time = 5.0

        env = ThomasEnvironment(
            delegate: delegate,
            extensions: nil,
            pagerTracker: nil,
            timer: timer,
            onDismiss: {
                // Attempt to dismiss again from within callback
                recursiveCallAttempted = true
                env.dismiss()
            }
        )

        env.dismiss()

        // Should be dismissed only once
        #expect(env.isDismissed)
        #expect(recursiveCallAttempted)
        #expect(delegate.dismissals.count == 1)
        #expect(delegate.reportedEvents.count == 1)
    }

    // MARK: - Pager Summary Tests

    @Test
    func testPagerSummaryEmittedBeforeDismiss() {
        let tracker = ThomasPagerTracker()
        let (env, delegate, timer) = makeEnvironment(pagerTracker: tracker)

        let pagerState = PagerState(identifier: "test-pager", branching: nil)
        let pageInfo = ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1)

        // View a page
        timer.time = 0
        env.pageViewed(pagerState: pagerState, pageInfo: pageInfo, layoutState: .empty)

        timer.time = 10.0
        env.dismiss()

        // Should have pageView, pagerSummary, then dismiss - in that order
        #expect(delegate.reportedEvents.count == 3)

        // Verify order
        if case .pageView = delegate.reportedEvents[0] {
            // Correct
        } else {
            Issue.record("Expected pageView as first event")
        }

        if case .pagerSummary = delegate.reportedEvents[1] {
            // Correct - summary before dismiss
        } else {
            Issue.record("Expected pagerSummary before dismiss")
        }

        if case .dismiss = delegate.reportedEvents[2] {
            // Correct - dismiss last
        } else {
            Issue.record("Expected dismiss as last event")
        }
    }

    @Test
    func testPagerTrackerStoppedOnDismiss() {
        let tracker = ThomasPagerTracker()
        let (env, _, timer) = makeEnvironment(pagerTracker: tracker)

        // Track a page view using environment
        let pagerState = PagerState(identifier: "test-pager", branching: nil)
        let pageInfo = ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1)

        timer.time = 0
        env.pageViewed(pagerState: pagerState, pageInfo: pageInfo, layoutState: .empty)

        timer.time = 5.0
        env.dismiss()

        // Verify tracker was stopped (viewed pages should be captured)
        let viewedPages = tracker.viewedPages(pagerIdentifier: "test-pager")
        #expect(viewedPages.count == 1)
        #expect(viewedPages[0].displayTime == 5.0)
    }

    // MARK: - State Change Tests

    @Test
    func testStateChangeForwardedToDelegate() {
        let (env, delegate, _) = makeEnvironment()

        let state = AirshipJSON.object(["key": .string("value")])
        env.onStateChange(state)

        #expect(delegate.stateChanges.count == 1)
        #expect(delegate.stateChanges[0] == state)
    }

    // MARK: - Layout Context Tests

    @Test
    func testLayoutContextWithNilStates() {
        let (env, delegate, _) = makeEnvironment()

        env.buttonTapped(
            buttonIdentifier: "test",
            reportingMetadata: nil,
            layoutState: .empty
        )

        #expect(delegate.reportedEvents.count == 1)

        if case .buttonTap(_, let context) = delegate.reportedEvents[0] {
            #expect(context.pager == nil)
            #expect(context.form == nil)
        } else {
            Issue.record("Expected buttonTap event with context")
        }
    }

    // MARK: - Action Runner Tests

    @Test
    func testRunActionsWithNilPayload() {
        let (env, _, _) = makeEnvironment()

        // Should not crash with nil payload
        env.runActions(nil, layoutState: .empty)
    }

    @Test
    func testRunActionsWithEmptyValue() {
        let (env, _, _) = makeEnvironment()

        // Create payload with nil value
        let emptyPayload = ThomasActionsPayload(value: .null)

        // Should return early when value is nil
        env.runActions(emptyPayload, layoutState: .empty)
    }

    @Test
    func testRunActionsWithCustomRunner() {
        let testRunner = TestThomasActionRunner()
        let extensions = ThomasExtensions(
            imageProvider: nil,
            actionRunner: testRunner
        )
        let (env, _, _) = makeEnvironment(extensions: extensions)

        let payload = ThomasActionsPayload(value: .object(["test_action": .string("test_value")]))

        env.runActions(payload, layoutState: .empty)

        // Verify custom runner was called
        #expect(testRunner.runAsyncCalled)
        #expect(testRunner.lastActions != nil)
    }

    @Test
    func testRunActionWithCustomRunner() async {
        let testRunner = TestThomasActionRunner()
        let extensions = ThomasExtensions(
            imageProvider: nil,
            actionRunner: testRunner
        )
        let (env, _, _) = makeEnvironment(extensions: extensions)

        let arguments = ActionArguments(
            string: "test_value",
            situation: .automation
        )

        _ = await env.runAction(
            "test_action",
            arguments: arguments,
            layoutState: .empty
        )

        // Verify custom runner was called
        #expect(testRunner.runCalled)
        #expect(testRunner.lastActionName == "test_action")
    }

    // MARK: - Integration Tests

    @Test
    func testFullLifecycleWithPager() {
        let tracker = ThomasPagerTracker()
        let (env, delegate, timer) = makeEnvironment(pagerTracker: tracker)

        // Initialize - not visible
        #expect(!timer.isStarted)

        // Make visible and foregrounded
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)

        // View pages
        let pagerState = PagerState(identifier: "lifecycle-pager", branching: nil)
        timer.time = 1.0
        env.pageViewed(pagerState: pagerState, pageInfo: ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1), layoutState: .empty)

        timer.time = 5.0
        env.pageViewed(pagerState: pagerState, pageInfo: ThomasPageInfo(identifier: "page-1", index: 1, viewCount: 1), layoutState: .empty)

        // Background
        env.onVisibilityChanged(isVisible: true, isForegrounded: false)
        #expect(!timer.isStarted)

        // Foreground again
        env.onVisibilityChanged(isVisible: true, isForegrounded: true)
        #expect(timer.isStarted)

        // Dismiss
        timer.time = 10.0
        env.dismiss(buttonIdentifier: "close", buttonDescription: "Close", cancel: false, layoutState: .empty)

        // Verify full sequence
        #expect(env.isDismissed)
        #expect(!timer.isStarted)
        #expect(delegate.visibilityChanges.count == 3)

        // Events: 2 pageViews + 1 pagerSummary + 1 dismiss
        #expect(delegate.reportedEvents.count == 4)

        // Verify summary came before dismiss
        if case .pagerSummary = delegate.reportedEvents[2] {
            // Correct
        } else {
            Issue.record("Expected pagerSummary before dismiss")
        }

        if case .dismiss = delegate.reportedEvents[3] {
            // Correct
        } else {
            Issue.record("Expected dismiss last")
        }
    }

    @Test
    func testPagerTrackerIsolationBetweenEnvironments() {
        let sharedTracker = ThomasPagerTracker()

        // Create two environments sharing same tracker
        let (env1, delegate1, timer1) = makeEnvironment(pagerTracker: sharedTracker)
        let (env2, delegate2, timer2) = makeEnvironment(pagerTracker: sharedTracker)

        let pagerState = PagerState(identifier: "shared-pager", branching: nil)

        // View page in env1
        timer1.time = 0
        env1.pageViewed(pagerState: pagerState, pageInfo: ThomasPageInfo(identifier: "page-0", index: 0, viewCount: 1), layoutState: .empty)

        // View page in env2
        timer2.time = 5.0
        env2.pageViewed(pagerState: pagerState, pageInfo: ThomasPageInfo(identifier: "page-1", index: 1, viewCount: 1), layoutState: .empty)

        // Dismiss env1
        timer1.time = 10.0
        env1.dismiss()

        // Env1 should have pager summary
        let env1Summaries = delegate1.reportedEvents.filter {
            if case .pagerSummary = $0 { return true }
            return false
        }
        #expect(env1Summaries.count == 1)

        // Env2 should still be able to emit its own summary
        timer2.time = 15.0
        env2.dismiss()

        let env2Summaries = delegate2.reportedEvents.filter {
            if case .pagerSummary = $0 { return true }
            return false
        }
        #expect(env2Summaries.count == 1)
    }
}

// MARK: - Test Action Runner

@MainActor
final class TestThomasActionRunner: ThomasActionRunner {
    var runAsyncCalled = false
    var runCalled = false
    var lastActions: AirshipJSON?
    var lastActionName: String?
    var lastLayoutContext: ThomasLayoutContext?

    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext) {
        runAsyncCalled = true
        lastActions = actions
        lastLayoutContext = layoutContext
    }

    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult {
        runCalled = true
        lastActionName = actionName
        lastLayoutContext = layoutContext
        return .completed(AirshipJSON.null)
    }
}
