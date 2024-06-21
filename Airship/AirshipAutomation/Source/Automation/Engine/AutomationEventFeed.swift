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
    case stateChanged(state: TriggerableState)
    case event(type: EventAutomationTriggerType, data: AirshipJSON? = nil, value: Double = 1.0)
    
    var eventData: AirshipJSON? {
        switch self {
        case .event(_, let data, _): return data
        default: return nil
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

    private let applicationMetrics: ApplicationMetricsProtocol
    private let applicationStateTracker: AppStateTrackerProtocol
    private let analyticsFeed: AirshipAnalyticsFeed

    private var appSessionState = TriggerableState()
    private var regions: Set<String> = Set()

    let feed: Stream

    init(
        applicationMetrics: ApplicationMetricsProtocol,
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

            self.continuation.yield(.event(type: .appInit))

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
                            await onEvent(.event(type: .foreground))
                        }

                        if (state == .background) {
                            await onEvent(.event(type: .background))
                        }
                    }
                }

                group.addTask {
                    for await event in await analyticsFeed.updates {
                        guard !Task.isCancelled else { return }
                        guard let converted = event.toAutomationEvent() else { continue }
                        
                        for item in converted {
                            await onEvent(item)
                        }
                    }
                }
            }
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
        case .event(let type, _, _):
            switch type {
            case .foreground:
                self.setAppSessionID(UUID().uuidString)
            case .background:
                self.setAppSessionID(nil)
            default: break
            }
        default: break
        }
    }
}

private extension AirshipAnalyticsFeed.Event {
    
    func toAutomationEvent() -> [AutomationEvent]? {
        switch self {
        case .screen(let screen):
            return [.event(type: .screen, data: try? AirshipJSON.wrap(screen))]
        case .analytics(let eventType, let body, let value):
            switch eventType {
            case .regionEnter:
                return [.event(type: .regionEnter, data: body)]
            case .regionExit:
                return [.event(type: .regionExit, data: body)]
            case .customEvent:
                return [
                    .event(type: .customEventCount, data: body),
                    .event(type: .customEventValue, data: body, value: value ?? 1.0)
                ]
            case .featureFlagInteraction:
                return [.event(type: .featureFlagInteraction, data: body)]
            case .inAppDisplay:
                return [.event(type: .inAppDisplay, data: body)]
            case .inAppResolution:
                return [.event(type: .inAppResolution, data: body)]
            case .inAppButtonTap:
                return [.event(type: .inAppButtonTap, data: body)]
            case .inAppPermissionResult:
                return [.event(type: .inAppPermissionResult, data: body)]
            case .inAppFormDisplay:
                return [.event(type: .inAppFormDisplay, data: body)]
            case .inAppFormResult:
                return [.event(type: .inAppFormResult, data: body)]
            case .inAppGesture:
                return [.event(type: .inAppGesture, data: body)]
            case .inAppPagerCompleted:
                return [.event(type: .inAppPagerCompleted, data: body)]
            case .inAppPagerSummary:
                return [.event(type: .inAppPagerSummary, data: body)]
            case .inAppPageSwipe:
                return [.event(type: .inAppPageSwipe, data: body)]
            case .inAppPageView:
                return [.event(type: .inAppPageView, data: body)]
            case .inAppPageAction:
                return [.event(type: .inAppPageAction, data: body)]
            default:
                return nil
            }
#if canImport(AirshipCore)
        @unknown default:
            return nil
#endif
        }
    }
}
