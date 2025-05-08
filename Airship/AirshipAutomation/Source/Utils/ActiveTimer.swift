/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class ActiveTimer: AirshipTimerProtocol {

    private var isStarted: Bool = false
    private var isActive: Bool
    private var elapsedTime: TimeInterval = 0
    private var startDate: Date? = nil
    private let notificationCenter: AirshipNotificationCenter
    private let dateFetcher: any AirshipDateProtocol
    
    init(
        appStateTracker: (any AppStateTrackerProtocol)? = nil,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) { 
        
        self.notificationCenter = notificationCenter
        self.dateFetcher = date
        
        let stateTracker = appStateTracker ?? AppStateTracker.shared
        self.isActive = stateTracker.state == .active
        
        notificationCenter.addObserver(self, selector: #selector(onApplicationBecomeActive),
                                       name: AppStateTracker.didBecomeActiveNotification)
        
        notificationCenter.addObserver(self, selector: #selector(onApplicationWillResignActive),
                                       name: AppStateTracker.willResignActiveNotification)
    }
    
    deinit {
        self.notificationCenter.removeObserver(self)
    }
    
    func start() {
        guard !self.isStarted else { return }
        
        if self.isActive {
            self.startDate = dateFetcher.now
        }
        
        self.isStarted = true
    }
    
    func stop() {
        guard self.isStarted else { return }
        
        self.elapsedTime += currentSessionTime()
        self.startDate = nil
        
        self.isStarted = false
    }
    
    private func currentSessionTime() -> TimeInterval {
        guard let date = self.startDate else { return 0 }
        return self.dateFetcher.now.timeIntervalSince(date)
    }
    
    @objc
    private func onApplicationBecomeActive() {
        self.isActive = true
        if self.isStarted, self.startDate == nil {
            self.startDate = dateFetcher.now
        }
    }
    
    @objc
    private func onApplicationWillResignActive() {
        self.isActive = false
        stop()
    }
    
    var time: TimeInterval {
        return self.elapsedTime + currentSessionTime()
    }
    
}
