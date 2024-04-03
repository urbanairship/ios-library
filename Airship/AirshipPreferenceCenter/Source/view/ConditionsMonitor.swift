/* Copyright Airship and Contributors */

import Combine
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
class ConditionsMonitor: ObservableObject {
    @Published
    public private(set) var isMet: Bool = true

    private let conditions: [PreferenceCenterConfig.Condition]
    private var cancellable: AnyCancellable?

    init(conditions: [PreferenceCenterConfig.Condition]) {
        self.conditions = conditions

        Task { @MainActor [weak self] in
            self?.updateConditions()
        }

        let conditionUpdates = conditions.map { self.conditionUpdates($0) }
        self.cancellable = Publishers.MergeMany(conditionUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateConditions()
                }
            }
    }

    @MainActor
    private func updateConditions() {
        self.isMet = self.checkConditions()
    }

    private func conditionUpdates(_ condition: PreferenceCenterConfig.Condition)
        -> AnyPublisher<Bool, Never>
    {
        guard Airship.isFlying else {
            return Just(true).eraseToAnyPublisher()
        }

        switch condition {
        case .notificationOptIn(_):
            return Airship.push.notificationStatusPublisher.map { status in
                status.isUserOptedIn
            }
            .eraseToAnyPublisher()
        case .smsOptIn(_):
            return Airship.contact.channelOptinStatusPublisher.map { status in
                guard let smsOptinStatus = status.filter({ $0.type == .sms }).first else {
                    return false
                }
                return smsOptinStatus.status == .optIn
            }
            .eraseToAnyPublisher()
            
        case .emailOptIn(_):
            return Airship.contact.channelOptinStatusPublisher.map { status in
                guard let emailOptinStatus = status.filter({ $0.type == .email }).first else {
                    return false
                }
                return emailOptinStatus.status == .optIn
            }
            .eraseToAnyPublisher()
        }

    }

    @MainActor
    private func checkConditions() -> Bool {
        let conditionResults = self.conditions.map { self.checkCondition($0) }
        return !conditionResults.contains(false)
    }

    @MainActor
    private func checkCondition(_ condition: PreferenceCenterConfig.Condition)
        -> Bool
    {
        guard Airship.isFlying else {
            return true
        }

        switch condition {
        case .notificationOptIn(let condition):
            switch condition.optInStatus {
            case .optedIn:
                return Airship.push.isPushNotificationsOptedIn
            case .optedOut:
                return !Airship.push.isPushNotificationsOptedIn
            }
        case .smsOptIn(let condition):
            return isOptin(type: .sms, condition: condition)
        case .emailOptIn(let condition):
            return isOptin(type: .email, condition: condition)
        }
    }
    
    private func isOptin(
        type: ChannelType,
        condition: PreferenceCenterConfig.OptInCondition
    ) -> Bool {
        
        guard let channelOptinStatus = Airship.contact.channelOptinStatus else {
            return false
        }
        
        guard let optinStatus = channelOptinStatus.filter({ $0.type == type }).first else {
            return false
        }
        
        switch condition.optInStatus {
        case .optedIn: return optinStatus.status == .optIn
        case .optedOut: return optinStatus.status == .optOut
        }
    }
}


