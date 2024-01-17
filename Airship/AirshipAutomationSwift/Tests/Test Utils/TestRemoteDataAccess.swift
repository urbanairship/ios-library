/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestRemoteDataAccess: AutomationRemoteDataAccessProtocol, @unchecked Sendable {
    func source(forSchedule schedule: AirshipAutomationSwift.AutomationSchedule) -> AirshipCore.RemoteDataSource? {
        return .app
    }

    
    var isCurrentBlock: ((AutomationSchedule) async -> Bool)?
    var bestEffortRefreshBlock: ((AutomationSchedule) async -> Bool)?
    var requiresUpdateBlock: ((AutomationSchedule) async -> Bool)?
    var waitFullRefreshBlock: ((AutomationSchedule) async -> Void)?

    var contactIDBlock: ((AutomationSchedule) -> String?)?

    var notifiedOutdatedSchedules: [AutomationSchedule] = []

    let updatesSubject = PassthroughSubject<InAppRemoteData, Never>()

    var publisher: AnyPublisher<InAppRemoteData, Never> {
        return updatesSubject.eraseToAnyPublisher()
    }

    func isCurrent(schedule: AutomationSchedule) async -> Bool {
        return await isCurrentBlock!(schedule)
    }

    func requiresUpdate(schedule: AutomationSchedule) async -> Bool {
        return await requiresUpdateBlock!(schedule)
    }


    func waitFullRefresh(schedule: AutomationSchedule) async {
        await waitFullRefreshBlock!(schedule)
    }

    func bestEffortRefresh(schedule: AutomationSchedule) async -> Bool {
        await bestEffortRefreshBlock!(schedule)
    }

    func notifyOutdated(schedule: AutomationSchedule) async {
        notifiedOutdatedSchedules.append(schedule)
    }

    func contactID(forSchedule schedule: AutomationSchedule) -> String? {
        return contactIDBlock!(schedule)
    }
}
