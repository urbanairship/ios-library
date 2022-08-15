/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

class ConditionsMonitor: ObservableObject {
    @Published
    public private(set) var isMet: Bool = false

    private let conditions: [PreferenceCenterConfig.Condition]
    private var cancellable: AnyCancellable?

    init(conditions: [PreferenceCenterConfig.Condition]) {
        self.conditions = conditions
        self.isMet = checkConditions()

        let conditionUpdates = conditions.map { self.conditionUpdates($0) }
        self.cancellable = Publishers.MergeMany(conditionUpdates)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { _ in
                self.isMet = self.checkConditions()
            })
    }

    private func conditionUpdates(_ condition: PreferenceCenterConfig.Condition) -> AnyPublisher<Bool, Never> {
        guard Airship.isFlying else {
            return Just(true).eraseToAnyPublisher()
        }

        switch(condition) {
        case .notificationOptIn(_):
            return Airship.push.optInUpdates
        }

    }

    private func checkConditions() -> Bool {
        let conditionResults = self.conditions.map { self.checkCondition($0) }
        return !conditionResults.contains(false)
    }

    private func checkCondition(_ condition: PreferenceCenterConfig.Condition) -> Bool {
        guard Airship.isFlying else {
            return true
        }
        
        switch(condition) {
        case .notificationOptIn(let condition):
            switch (condition.optInStatus) {
            case .optedIn:
                return Airship.push.isPushNotificationsOptedIn
            case .optedOut:
                return !Airship.push.isPushNotificationsOptedIn
            }
        }
    }
}
