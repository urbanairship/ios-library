/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationEventFeedProtocol: Sendable {
    var feed: AsyncStream<AutomationEvent> { get }
}

struct TriggerableState: Equatable, Codable {
    var appSessionID: String? // set on foreground event, resets on background
    var versionUpdated: String? // versionUpdate event
}

enum AutomationEvent: Sendable, Equatable {
    case foreground
    case background
    case screenView(name: String?)
    case appInit
    case stateChanged(state: TriggerableState)
    case regionEnter(regionId: String)
    case regionExit(regionId: String)
    case customEvent(data: AirshipJSON, value: Double?)
    case featureFlagInterracted(data: AirshipJSON)
    
    func reportPayload() -> AirshipJSON? {
        switch self {
        case .foreground, .background, .appInit, .stateChanged:
            return nil
        case .screenView(let name):
            return try? AirshipJSON.wrap(name)
        case .regionEnter(let regionId): 
            return try? AirshipJSON.wrap([
                "region_id": regionId,
                "type": "enter"
            ])
        case .regionExit(let regionId):
            return try? AirshipJSON.wrap([
                "region_id": regionId,
                "type": "exit"
            ])
        case .customEvent(let data, _):
            return data
        case .featureFlagInterracted(let data):
            return data
        }
    }
}

@MainActor
final class AutomationEventFeed: AutomationEventFeedProtocol {
    typealias Stream = AsyncStream<AutomationEvent>
    
    private let continuation: Stream.Continuation
    private let notificationCenter: AirshipNotificationCenter
    private var observers: [AnyObject] = []
    private var isFirstAttach = false
    private var isAttached = false
    private let applicationMetrics: ApplicationMetrics
    
    private var appSessionState = TriggerableState()
    
    let feed: Stream

    init(
        metrics: ApplicationMetrics,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared
    ) {
        self.notificationCenter = notificationCenter
        (self.feed, self.continuation) = Stream.airshipMakeStreamWithContinuation()
        
        self.applicationMetrics = metrics
        
        self.listenToAppStateEvents()
        self.listenToAnalyticsEvents()
    }
    
    @discardableResult
    func attach() -> Self {
        guard !isAttached else { return self }
        
        isAttached = true
        
        guard !isFirstAttach else { return self }
        
        isFirstAttach = true
        
        self.emit(event: .appInit)
        
        if 
            applicationMetrics.isAppVersionUpdated,
            let version = applicationMetrics.currentAppVersion
        {
            self.appSessionState.versionUpdated = version
            self.emit(event: .stateChanged(state: self.appSessionState))
        }
        
        return self
    }
    
    @discardableResult
    func detach() -> Self {
        isAttached = false
        return self
    }
    
    deinit {
        self.continuation.finish()
        observers.forEach(notificationCenter.removeObserver)
    }
    
    private func listenToAppStateEvents() {
        subscribeToNotification(name: AppStateTracker.didBecomeActiveNotification) { _ in
            return .foreground
        }
        
        subscribeToNotification(name: AppStateTracker.didEnterBackgroundNotification) { _ in
            return .background
        }
    }
    
    private func listenToAnalyticsEvents() {
        subscribeToNotification(name: AirshipAnalytics.featureFlagInterracted) { notification in
            guard
                let event = notification.userInfo?[AirshipAnalytics.eventKey] as? AirshipEvent,
                let data = try? AirshipJSON.wrap(event.data)
            else {
                return nil
            }
            
            return .featureFlagInterracted(data: data)
        }
        
        subscribeToNotification(name: AirshipAnalytics.screenTracked) { notification in
            let name = notification.userInfo?[AirshipAnalytics.screenKey] as? String
            return .screenView(name: name)
        }
        
        subscribeToNotification(name: AirshipAnalytics.customEventAdded) { notification in
            guard
                let event = notification.userInfo?[AirshipAnalytics.eventKey] as? CustomEvent,
                let data = try? AirshipJSON.wrap(event.data)
            else {
                return nil
            }
            
            return .customEvent(data: data, value: event.eventValue?.doubleValue)
        }
        
        subscribeToNotification(name: AirshipAnalytics.regionEventAdded) { notification in
            guard let event = notification.userInfo?[AirshipAnalytics.eventKey] as? RegionEvent else {
                return nil
            }
            
            switch event.boundaryEvent {
            case .enter:
                return .regionEnter(regionId: event.regionID)
            case .exit:
                return .regionExit(regionId: event.regionID)
            @unknown default:
                AirshipLogger.error("Invalid region event \(event)")
                return nil
            }
        }
    }
    
    private func subscribeToNotification(name: Notification.Name, closure: @escaping (Notification) -> AutomationEvent?) {
        let token = self.notificationCenter.addObserver(forName: name) { [weak self] notification in
            if let event = closure(notification) {
                self?.emit(event: event)
            }
        }
        
        self.observers.append(token)
    }
    
    private func setAppSessionID(_ id: String?) {
        self.appSessionState.appSessionID = id
        emit(event: .stateChanged(state: self.appSessionState))
    }
    
    private func emit(event: AutomationEvent) {
        guard isAttached else { return }
        self.continuation.yield(event)
        
        switch event {
        case .foreground:
            self.setAppSessionID(UUID().uuidString)
        case .background:
            self.setAppSessionID(nil)
        default: break
        }
    }
}
