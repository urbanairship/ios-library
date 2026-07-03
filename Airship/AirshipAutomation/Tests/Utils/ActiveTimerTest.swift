/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore

@MainActor
struct ActiveTimerTest {
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let notificationCenter = NotificationCenter()
    private let stateTracker = TestAppStateTracker()
    
    private func createSubject(state: AirshipCore.ApplicationState = .active) -> ActiveTimer {
        stateTracker.currentState = state
        
        return ActiveTimer(
            appStateTracker: stateTracker,
            notificationCenter: AirshipNotificationCenter(notificationCenter: notificationCenter),
            date: date
        )
    }

    @Test
    func testManualStartStopWorks() {
        let subject = createSubject()
        
        subject.start()
        date.offset = 2
        
        #expect(2 == subject.time)
        
        date.offset = 3
        subject.stop()
        #expect(3 == subject.time)
    }
    
    @Test
    func testMultipleSessions() {
        let subject = createSubject()
        subject.start()
        date.offset = 1
        #expect(1 == subject.time)
        subject.stop()
        
        date.offset += 1
        #expect(1 == subject.time)
        subject.start()
        date.offset += 2
        subject.stop()
        #expect(3 == subject.time)
        
        date.offset += 1
        #expect(3 == subject.time)
    }
    
    @Test
    func testStartDoesntWorkIfAppInBackground() {
        let subject = createSubject(state: .background)
        subject.start()
        date.offset = 2
        
        #expect(0 == subject.time)
    }
    
    @Test
    func testDoubleStartDoesntRestCounter() {
        let subject = createSubject()
        
        subject.start()
        date.offset = 2
        #expect(2 == subject.time)
        date.offset = 3
        subject.start()
        date.offset = 2
        subject.stop()
        #expect(2 == subject.time)
    }
    
    @Test
    func testDoubleStopDoesntDoubleCounter() {
        let subject = createSubject()
        subject.start()
        date.offset = 3
        subject.stop()
        
        #expect(3 == subject.time)
        
        date.offset = 5
        subject.stop()
        
        #expect(3 == subject.time)
    }
    
    @Test
    func testHandlingAppState() {
        let subject = createSubject(state: .background)
        
        subject.start()
        date.offset = 3
        #expect(0 == subject.time)
        notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        date.offset += 3
        #expect(3 == subject.time)
        
        notificationCenter.post(name: AppStateTracker.willResignActiveNotification, object: nil)
        date.offset = 5
        #expect(3 == subject.time)
    }
    
    @Test
    func testActiveNotificationDoesNothingOnDisabledTimer() {
        let subject = createSubject(state: .background)
        #expect(0 == subject.time)
        
        notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        date.offset += 3
        #expect(0 == subject.time)
        
    }
    
    @Test
    func testTimerStopsOnEnteringBackground() {
        let subject = createSubject()
        subject.start()
        date.offset = 2
        #expect(2 == subject.time)
        
        notificationCenter.post(name: AppStateTracker.willResignActiveNotification, object: nil)
        date.offset = 5
        #expect(2 == subject.time)
        
        subject.stop()
        #expect(2 == subject.time)
    }
    
}
