/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
@testable import AirshipCore

final class ActiveTimerTest: XCTestCase {
    var subject: ActiveTimer!
    
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let notificationCenter = NotificationCenter()
    private let stateTracker = TestAppStateTracker()
    
    @MainActor
    private func createSubject(state: AirshipCore.ApplicationState = .active) {
        stateTracker.currentState = state
        
        subject = ActiveTimer(
            appStateTracker: stateTracker,
            notificationCenter: AirshipNotificationCenter(notificationCenter: notificationCenter),
            date: date
        )
    }

    @MainActor
    func testManualStartStopWorks() {
        createSubject()
        
        subject.start()
        date.offset = 2
        
        XCTAssertEqual(2, subject.time)
        
        date.offset = 3
        subject.stop()
        XCTAssertEqual(3, subject.time)
    }
    
    @MainActor
    func testMultipleSessions() {
        createSubject()
        subject.start()
        date.offset = 1
        XCTAssertEqual(1, subject.time)
        subject.stop()
        
        date.offset += 1
        XCTAssertEqual(1, subject.time)
        subject.start()
        date.offset += 2
        subject.stop()
        XCTAssertEqual(3, subject.time)
        
        date.offset += 1
        XCTAssertEqual(3, subject.time)
    }
    
    @MainActor
    func testStartDoesntWorkIfAppInBackground() {
        createSubject(state: .background)
        subject.start()
        date.offset = 2
        
        XCTAssertEqual(0, subject.time)
    }
    
    @MainActor
    func testDoubleStartDoesntRestCounter() {
        createSubject()
        
        subject.start()
        date.offset = 2
        XCTAssertEqual(2, subject.time)
        date.offset = 3
        subject.start()
        date.offset = 2
        subject.stop()
        XCTAssertEqual(2, subject.time)
    }
    
    @MainActor
    func testDoubleStopDoesntDoubleCounter() {
        createSubject()
        subject.start()
        date.offset = 3
        subject.stop()
        
        XCTAssertEqual(3, subject.time)
        
        date.offset = 5
        subject.stop()
        
        XCTAssertEqual(3, subject.time)
    }
    
    @MainActor
    func testHandlingAppState() {
        createSubject(state: .background)
        
        subject.start()
        date.offset = 3
        XCTAssertEqual(0, subject.time)
        notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        date.offset += 3
        XCTAssertEqual(3, subject.time)
        
        notificationCenter.post(name: AppStateTracker.willResignActiveNotification, object: nil)
        date.offset = 5
        XCTAssertEqual(3, subject.time)
    }
    
    @MainActor
    func testActiveNotificationDoesNothingOnDisabledTimer() {
        createSubject(state: .background)
        XCTAssertEqual(0, subject.time)
        
        notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        date.offset += 3
        XCTAssertEqual(0, subject.time)
        
    }
    
    @MainActor
    func testTimerStopsOnEnteringBackground() {
        createSubject()
        subject.start()
        date.offset = 2
        XCTAssertEqual(2, subject.time)
        
        notificationCenter.post(name: AppStateTracker.willResignActiveNotification, object: nil)
        date.offset = 5
        XCTAssertEqual(2, subject.time)
        
        subject.stop()
        XCTAssertEqual(2, subject.time)
    }
    
}
