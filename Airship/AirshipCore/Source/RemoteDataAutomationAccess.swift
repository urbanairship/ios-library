/* Copyright Airship and Contributors */

import Foundation


// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataAutomationAccess)
public final class _RemoteDataAutomationAccess: NSObject {
    private let remoteData: RemoteDataProtocol
    private let serialQueues: [RemoteDataSource: SerialQueue]
    private let remoteDataRefresher: BestEffortRefresher

    init(
        remoteData: RemoteDataProtocol,
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.remoteData = remoteData
        self.remoteDataRefresher = BestEffortRefresher(remoteData: remoteData, networkMonitor: networkMonitor)

        var queues: [RemoteDataSource: SerialQueue] = [:]
        RemoteDataSource.allCases.forEach { source in
            queues[source] = SerialQueue()
        }
        self.serialQueues = queues
    }

    @objc
    public func subscribe(types: [String], block: @escaping ([RemoteDataPayload]) -> Void) -> Disposable {
        let cancellable = remoteData.publisher(types: types)
                  .receive(on: RunLoop.main)
                  .sink { payloads in
                      block(payloads)
                  }

        return Disposable {
            cancellable.cancel()
        }
    }

    @objc
    public func isCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        return await remoteDataRefresher.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func refreshAndCheckCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        let source = remoteDataInfo?.source ?? .app
        await self.runInQueue(source: source) { [remoteDataRefresher] in
            await remoteDataRefresher.bestEffortRefresh(
                remoteDataInfo: remoteDataInfo,
                source: source
            )
        }

        return await isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func refreshOutdated(remoteDataInfo: RemoteDataInfo?) async {
        let source = remoteDataInfo?.source ?? .app
        await self.runInQueue(source: source) { [remoteDataRefresher] in
            await remoteDataRefresher.refreshOutdated(
                remoteDataInfo: remoteDataInfo,
                source: source
            )
        }
    }

    private func runInQueue(source: RemoteDataSource, block: @escaping @Sendable () async -> Void) async {
        await self.serialQueues[source]?.runSafe(work: block)
    }
}

fileprivate actor BestEffortRefresher {
    private let remoteData: RemoteDataProtocol
    private let networkMonitor: NetworkMonitor

    init(remoteData: RemoteDataProtocol, networkMonitor: NetworkMonitor) {
        self.remoteData = remoteData
        self.networkMonitor = networkMonitor
    }

    func refreshOutdated(
        remoteDataInfo: RemoteDataInfo?,
        source: RemoteDataSource
    ) async {
        guard
            let remoteDataInfo = remoteDataInfo,
            await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        else {
            await bestEffortRefresh(
                remoteDataInfo: remoteDataInfo,
                source: source
            )
            return
        }

        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        await refreshSource(source: source)
    }

    func isCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        guard let remoteDataInfo = remoteDataInfo else {
            return false
        }
        return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    func bestEffortRefresh(remoteDataInfo: RemoteDataInfo?, source: RemoteDataSource) async {
        if await isCurrent(remoteDataInfo: remoteDataInfo) {
            if await self.remoteData.status(source: source) != .upToDate, networkMonitor.isConnected {
                await refreshSource(source: source)
            }
            return
        }
        
        await refreshSource(source: source)
    }

    private func refreshSource(source: RemoteDataSource) async {
        AirshipLogger.trace("Attempting to refresh source \(source)")
        if await self.remoteData.refresh(source: source) {
            AirshipLogger.trace("Refreshed source \(source)")
        } else {
            AirshipLogger.trace("Failed to refresh source \(source)")
        }
    }
}
