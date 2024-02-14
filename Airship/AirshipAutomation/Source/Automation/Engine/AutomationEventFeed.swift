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
    case regionEnter(data: AirshipJSON)
    case regionExit(data: AirshipJSON)
    case customEvent(data: AirshipJSON, value: Double?)
    case featureFlagInterracted(data: AirshipJSON)
    
    func reportPayload() -> AirshipJSON? {
        switch self {
        case .foreground, .background, .appInit, .stateChanged:
            return nil
        case .screenView(let name):
            return try? AirshipJSON.wrap(name)
        case .regionEnter(let data):
            return data
        case .regionExit(let data):
            return data
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
    private var observers: [AnyObject] = []
    private var isFirstAttach = false
    private var listenerTask: Task<Void, Never>?

    private let applicationMetrics: ApplicationMetrics
    private let applicationStateTracker: AppStateTrackerProtocol
    private let analyticsFeed: AirshipAnalyticsFeed

    private var appSessionState = TriggerableState()
    private var regions: Set<String> = Set()

    fileprivate enum AnalyticEventFilter: String {
        case featureFlagInteraction = "feature_flag_interaction"
        case customEvent = "enhanced_custom_event"
    }

    let feed: Stream

    init(
        applicationMetrics: ApplicationMetrics,
        applicationStateTracker: AppStateTrackerProtocol,
        analyticsFeed: AirshipAnalyticsFeed
    ) {
        self.applicationMetrics = applicationMetrics
        self.applicationStateTracker = applicationStateTracker
        self.analyticsFeed = analyticsFeed

        (self.feed, self.continuation) = Stream.airshipMakeStreamWithContinuation()
    }
    
    @discardableResult
    func attach() -> Self {
        guard listenerTask == nil else { return self }

        if !isFirstAttach {
            isFirstAttach = true

            self.continuation.yield(.appInit)

            if
                applicationMetrics.isAppVersionUpdated,
                let version = applicationMetrics.currentAppVersion
            {
                self.appSessionState.versionUpdated = version
                self.continuation.yield(.stateChanged(state: self.appSessionState))
            }
        }

        self.listenerTask = startListenerTask { [weak self] event in
            self?.emit(event: event)
        }

        return self
    }
    
    @discardableResult
    func detach() -> Self {
        self.listenerTask?.cancel()
        return self
    }
    
    deinit {
        self.listenerTask?.cancel()
        self.continuation.finish()
    }

    private func startListenerTask(
        onEvent: @escaping @Sendable @MainActor (AutomationEvent) -> Void
    ) -> Task<Void, Never> {
        return Task { [analyticsFeed, applicationStateTracker] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await state in await applicationStateTracker.stateUpdates {
                        guard !Task.isCancelled else { return }

                        if (state == .active) {
                            await onEvent(.foreground)
                        }

                        if (state == .background) {
                            await onEvent(.background)
                        }
                    }
                }

                group.addTask {
                    for await event in analyticsFeed.updates {
                        guard !Task.isCancelled else { return }
                        if let event = await Self.parseEvent(event: event) {
                            await onEvent(event)
                        }
                    }
                }
            }
        }
    }


    private class func parseEvent(event: AirshipAnalyticsFeed.Event) -> AutomationEvent? {
        switch(event) {
        case .customEvent(body: let body, value: let value):
            return .customEvent(data: body, value: value)
        case .regionEnter(body: let body):
            return .regionEnter(data: body)
        case .regionExit(body: let body):
            return .regionExit(data: body)
        case .featureFlagInteraction(body: let body):
            return .featureFlagInterracted(data: body)
        case .screenChange(screen: let screen):
            return .screenView(name: screen)
#if canImport(AirshipCore)
        @unknown default:
            return nil
#endif
        }

    }
    
    private func setAppSessionID(_ id: String?) {
        guard self.appSessionState.appSessionID != id else { return }
        self.appSessionState.appSessionID = id
        emit(event: .stateChanged(state: self.appSessionState))
    }

    private func emit(event: AutomationEvent) {
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
