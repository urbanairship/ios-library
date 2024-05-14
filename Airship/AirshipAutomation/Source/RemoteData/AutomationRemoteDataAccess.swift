/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Remote data access for automation
protocol AutomationRemoteDataAccessProtocol: Sendable {
    var publisher: AnyPublisher<InAppRemoteData, Never> { get }
    func isCurrent(schedule: AutomationSchedule) async -> Bool
    func requiresUpdate(schedule: AutomationSchedule) async -> Bool
    func waitFullRefresh(schedule: AutomationSchedule) async
    func bestEffortRefresh(schedule: AutomationSchedule) async -> Bool
    func notifyOutdated(schedule: AutomationSchedule) async
    func contactID(forSchedule schedule: AutomationSchedule) -> String?
    func source(forSchedule schedule: AutomationSchedule) -> RemoteDataSource?
}

final class AutomationRemoteDataAccess: AutomationRemoteDataAccessProtocol {
    private let remoteData: RemoteDataProtocol
    private let network: AirshipNetworkCheckerProtocol

    private static let remoteDataTypes = ["in_app_messages"]

    init(
        remoteData: RemoteDataProtocol,
        network: AirshipNetworkCheckerProtocol = AirshipNetworkChecker()
    ) {
        self.remoteData = remoteData
        self.network = network
    }

    var publisher: AnyPublisher<InAppRemoteData, Never> {
        return remoteData.publisher(types: Self.remoteDataTypes)
            .map { payloads in
                InAppRemoteData.fromPayloads(payloads)
            }
            .eraseToAnyPublisher()
    }

    func isCurrent(schedule: AutomationSchedule) async -> Bool {
        guard isRemoteSchedule(schedule) else {
            return true
        }
        
        guard let remoteDataInfo = remoteDataInfo(forSchedule: schedule) else {
            return false
        }

        return await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    func requiresUpdate(schedule: AutomationSchedule) async -> Bool {
        guard isRemoteSchedule(schedule) else {
            return false
        }

        guard 
            let remoteDataInfo = remoteDataInfo(forSchedule: schedule),
            await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        else {
            return true
        }

        let source = remoteDataInfo.source
        switch(await remoteData.status(source: source)) {
        case .outOfDate:
            return true
        case .stale:
            return false
        case .upToDate:
            return false
#if canImport(AirshipCore)
        @unknown default:
            return false
#endif
        }
    }

    func waitFullRefresh(schedule: AutomationSchedule) async {
        guard isRemoteSchedule(schedule) else {
            return
        }

        let source = remoteDataInfo(forSchedule: schedule)?.source ?? .app
        await self.remoteData.waitRefresh(source: source)
    }

    func bestEffortRefresh(schedule: AutomationSchedule) async -> Bool {
        guard isRemoteSchedule(schedule) else {
            return true
        }

        guard 
            let remoteDataInfo = remoteDataInfo(forSchedule: schedule),
            await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        else {
            return false
        }

        let source = remoteDataInfo.source
        if await self.remoteData.status(source: source) == .upToDate {
            return true
        }

        // if we are connected wait for refresh
        if (await network.isConnected) {
            await remoteData.waitRefreshAttempt(source: source)
        }

        return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    func notifyOutdated(schedule: AutomationSchedule) async {
        if let remoteDataInfo = remoteDataInfo(forSchedule: schedule) {
            await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        }
    }

    func contactID(forSchedule schedule: AutomationSchedule) -> String? {
        return remoteDataInfo(forSchedule: schedule)?.contactID
    }

    func source(forSchedule schedule: AutomationSchedule) -> RemoteDataSource? {
        guard self.isRemoteSchedule(schedule) else {
            return nil
        }
        return remoteDataInfo(forSchedule: schedule)?.source ?? .app
    }

    private func isRemoteSchedule(_ schedule: AutomationSchedule) -> Bool {
        if case .object(let map) = schedule.metadata {
            if map[InAppRemoteData.remoteInfoMetadataKey] != nil {
                return true
            }

            if map[InAppRemoteData.legacyRemoteInfoMetadataKey] != nil {
                return true
            }
        }

        // legacy way
        if case .inAppMessage(let message) = schedule.data {
            return message.source == .remoteData
        }

        return false
    }

    private func remoteDataInfo(forSchedule schedule: AutomationSchedule) -> RemoteDataInfo? {
        guard case .object(let map) = schedule.metadata else {
            return nil
        }

        guard let remoteInfoJson = map[InAppRemoteData.remoteInfoMetadataKey] else {
            return nil
        }


        do {
            if let json = remoteInfoJson.string {
                // 17.x and older
                let object = try AirshipJSON.from(json: json)
                return try object.decode()
            } else {
                return try remoteInfoJson.decode()
            }
        } catch {
            AirshipLogger.trace("Failed to parse remote info from schedule \(schedule) \(error)")
        }

        return nil
    }
}

struct InAppRemoteData: Sendable {
    static let legacyRemoteInfoMetadataKey: String = "com.urbanairship.iaa.REMOTE_DATA_METADATA"
    static let remoteInfoMetadataKey: String = "com.urbanairship.iaa.REMOTE_DATA_INFO";

    struct Data: Decodable, Equatable {
        var schedules: [AutomationSchedule]
        var constraints: [FrequencyConstraint]?

        enum CodingKeys: String, CodingKey {
            case schedules = "in_app_messages"
            case constraints = "frequency_constraints"
        }
        
        init(schedules: [AutomationSchedule], constraints: [FrequencyConstraint]? ) {
            self.schedules = schedules
            self.constraints = constraints
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let decodedSchedules = try container
                .decode([ScheduleOrError].self, forKey: .schedules)
                .compactMap { parsed in
                    switch(parsed) {
                    case .succeed(let result): return result
                    case .failed(let error):
                        AirshipLogger.warn("Failed to parse schedule \(error)")
                        return nil
                    }
                }
            
            self.schedules = decodedSchedules
            self.constraints = try container.decodeIfPresent([FrequencyConstraint].self, forKey: .constraints)
        }
    }

    struct Payload {
        var data: Data
        var timestamp: Date
        var remoteDataInfo: RemoteDataInfo?
    }

    var payloads: [RemoteDataSource: Payload]

    static func parsePayload(_ payload: RemoteDataPayload?) -> Payload? {
        guard let payload = payload else { return nil }
        do {
            let metadata = try AirshipJSON.wrap(
                [
                    legacyRemoteInfoMetadataKey: "",
                    remoteInfoMetadataKey: payload.remoteDataInfo
                ] as [String: AnyHashable]
            )

            var data: Data = try payload.data.decode()
            data.schedules.indices.forEach { i in
                data.schedules[i].metadata = metadata

                if case .inAppMessage(var message) = data.schedules[i].data {
                    message.source = .remoteData
                    data.schedules[i].data = .inAppMessage(message)
                }

                data.schedules[i].triggers.indices.forEach { j in
                    let trigger = data.schedules[i].triggers[j]
                    if (trigger.shouldBackFillIdentifier) {
                        data.schedules[i].triggers[j] = trigger.backfilledIdentifier(executionType: .execution)
                    }
                }

                if var delay = data.schedules[i].delay, var triggers = delay.cancellationTriggers {
                    triggers.indices.forEach { j in
                        let trigger = triggers[j]
                        if (trigger.shouldBackFillIdentifier) {
                            triggers[j] = trigger.backfilledIdentifier(executionType: .delayCancellation)
                        }
                    }
                    delay.cancellationTriggers = triggers
                    data.schedules[i].delay = delay
                }
            }

            return Payload(
                data: data,
                timestamp:payload.timestamp,
                remoteDataInfo: payload.remoteDataInfo
            )
        } catch {
            AirshipLogger.error("Failed to parse app remote-data response.")
        }

        return nil
    }

    static func fromPayloads(_ payloads: [RemoteDataPayload]) -> InAppRemoteData {
        var parsed: [RemoteDataSource: Payload] = [:]
        payloads.forEach { payload in
            parsed[payload.remoteDataInfo?.source ?? .app] = parsePayload(payload)
        }
        return InAppRemoteData(payloads: parsed)
    }
}

fileprivate enum ScheduleOrError: Decodable {

    case succeed(AutomationSchedule)
    case failed(Error)

    init(from decoder: any Decoder) throws {
        do {
            let schedule = try AutomationSchedule(from: decoder)
            self = .succeed(schedule)
        } catch {
            self = .failed(error)
        }
    }
}
