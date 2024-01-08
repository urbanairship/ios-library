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
}

final class AutomationRemoteDataAccess: AutomationRemoteDataAccessProtocol {
    private let remoteData: RemoteDataProtocol
    private let network: NetworkCheckerProtocol

    private static let remoteDataTypes = ["in_app_messages"]

    init(
        remoteData: RemoteDataProtocol,
        network: NetworkCheckerProtocol = NetworkChecker()
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
        guard isRemoteSchedule(schedule: schedule) else {
            return true
        }
        
        guard let remoteDataInfo = remoteDataInfo(schedule: schedule) else {
            return false
        }

        return await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    func requiresUpdate(schedule: AutomationSchedule) async -> Bool {
        guard isRemoteSchedule(schedule: schedule) else {
            return false
        }

        guard 
            let remoteDataInfo = remoteDataInfo(schedule: schedule),
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
        guard isRemoteSchedule(schedule: schedule) else {
            return
        }

        let source = remoteDataInfo(schedule: schedule)?.source ?? .app
        await self.remoteData.waitRefresh(source: source)
    }

    func bestEffortRefresh(schedule: AutomationSchedule) async -> Bool {
        guard isRemoteSchedule(schedule: schedule) else {
            return true
        }

        guard 
            let remoteDataInfo = remoteDataInfo(schedule: schedule),
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
        if let remoteDataInfo = remoteDataInfo(schedule: schedule) {
            await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        }
    }

    func contactID(forSchedule schedule: AutomationSchedule) -> String? {
        return remoteDataInfo(schedule: schedule)?.contactID
    }


    private func isRemoteSchedule(schedule: AutomationSchedule) -> Bool {
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

    private func remoteDataInfo(schedule: AutomationSchedule) -> RemoteDataInfo? {
        guard case .object(let map) = schedule.metadata else {
            return nil
        }

        guard let remoteInfoJson = map[InAppRemoteData.remoteInfoMetadataKey] else {
            return nil
        }

        do {
            return try remoteInfoJson.decode()
        } catch {
            AirshipLogger.error("Failed to parse remote info from schedule \(schedule) \(error)")
        }

        return nil
    }
}

struct InAppRemoteData {
    static let legacyRemoteInfoMetadataKey: String = "com.urbanairship.iaa.REMOTE_DATA_METADATA"
    static let remoteInfoMetadataKey: String = "com.urbanairship.iaa.REMOTE_DATA_INFO";

    struct Data: Decodable, Equatable {
        var schedules: [AutomationSchedule]
        var constraints: [FrequencyConstraint]?

        enum CodingKeys: String, CodingKey {
            case schedules = "in_app_messages"
            case constraints = "frequency_constraints"
        }
    }

    struct Payload {
        var data: Data
        var timestamp: Date
    }

    var contact: Payload?
    var app: Payload?


    static func parsePayload(_ payload: RemoteDataPayload?) -> Payload? {
        guard let payload = payload else { return nil }
        do {
            let metadata = try AirshipJSON.wrap(
                [
                    // We need to clear out the old legacy key for potential
                    // downgrades
                    legacyRemoteInfoMetadataKey: "",
                    remoteInfoMetadataKey: payload.remoteDataInfo
                ] as [String: AnyHashable]
            )

            var data: Data = try payload._data.decode()
            data.schedules.indices.forEach { i in
                data.schedules[i].metadata = metadata

                if case .inAppMessage(var message) = data.schedules[i].data {
                    message.source = .remoteData
                    data.schedules[i].data = .inAppMessage(message)
                }
            }

            return Payload(data: data, timestamp:payload.timestamp)
        } catch {
            AirshipLogger.error("Failed to parse app remote-data response.")
        }

        return nil
    }

    static func fromPayloads(_ payloads: [RemoteDataPayload]) -> InAppRemoteData {
        return InAppRemoteData(
            contact: parsePayload(
                payloads.first { payload in
                    payload.remoteDataInfo?.source == .contact
                }
            ),
            app: parsePayload(
                payloads.first { payload in
                    payload.remoteDataInfo == nil || payload.remoteDataInfo?.source == .app
                }
            )
        )
    }
}
