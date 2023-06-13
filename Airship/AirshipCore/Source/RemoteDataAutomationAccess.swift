/* Copyright Airship and Contributors */

import Foundation


@objc(UARemoteDataAutomationAccess)
public final class _RemoteDataAutomationAccess: NSObject {
    private let remoteData: RemoteDataProtocol
    private let notificationCenter: AirshipNotificationCenter
    private let serialQueues: [RemoteDataSource: SerialQueue]
    private let sessionNumber: Atomic<UInt> = Atomic(0)
    private let remoteDataRefresher: BestEffortRefresher

    init(
        remoteData: RemoteDataProtocol,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.notificationCenter = notificationCenter
        self.remoteData = remoteData
        self.remoteDataRefresher = BestEffortRefresher(remoteData: remoteData, networkMonitor: networkMonitor)

        var queues: [RemoteDataSource: SerialQueue] = [:]
        RemoteDataSource.allCases.forEach { source in
            queues[source] = SerialQueue()
        }
        self.serialQueues = queues

        super.init()
        
        notificationCenter.addObserver(
            self,
            selector: #selector(onAppForeground),
            name: AppStateTracker.willEnterForegroundNotification
        )
    }
    
    deinit {
        notificationCenter.removeObserver(self)
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
        let sessionNumber = self.sessionNumber.value
        let source = remoteDataInfo?.source ?? .app

        await self.runInQueue(source: source) { [remoteDataRefresher] in
            await remoteDataRefresher.bestEffortRefresh(
                remoteDataInfo: remoteDataInfo,
                source: source,
                sessionNumber: sessionNumber
            )
        }

        return await isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func refreshOutdated(remoteDataInfo: RemoteDataInfo?) async {
        let sessionNumber = self.sessionNumber.value
        let source = remoteDataInfo?.source ?? .app
        await self.runInQueue(source: source) { [remoteDataRefresher] in
            await remoteDataRefresher.refreshOutdated(
                remoteDataInfo: remoteDataInfo,
                source: source,
                sessionNumber: sessionNumber
            )
        }
    }
    
    @objc
    private func onAppForeground() {
        sessionNumber.value += 1
    }

    private func runInQueue(source: RemoteDataSource, block: @escaping @Sendable () async -> Void) async {
        await self.serialQueues[source]?.runSafe(work: block)
    }
}

fileprivate actor BestEffortRefresher {
    private var lastRefreshState: [RemoteDataSource: UInt] = [:]
    private let remoteData: RemoteDataProtocol
    private let networkMonitor: NetworkMonitor

    init(remoteData: RemoteDataProtocol, networkMonitor: NetworkMonitor) {
        self.remoteData = remoteData
        self.networkMonitor = networkMonitor
    }

    func refreshOutdated(
        remoteDataInfo: RemoteDataInfo?,
        source: RemoteDataSource,
        sessionNumber: UInt
    ) async {

        guard
            let remoteDataInfo = remoteDataInfo,
            await self.remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
        else {
            await bestEffortRefresh(
                remoteDataInfo: remoteDataInfo,
                source: source,
                sessionNumber: sessionNumber
            )
            return
        }

        self.lastRefreshState[source] = nil
        await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        await refreshSource(source: source, sessionNumber: sessionNumber)
    }

    func isCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        guard let remoteDataInfo = remoteDataInfo else {
            return false
        }
        return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    func bestEffortRefresh(remoteDataInfo: RemoteDataInfo?, source: RemoteDataSource, sessionNumber: UInt) async {
        if await isCurrent(remoteDataInfo: remoteDataInfo) {
            if lastRefreshState[source] != sessionNumber, networkMonitor.isConnected {
                await refreshSource(source: source, sessionNumber: sessionNumber)
            }
            return
        }
        
        await refreshSource(source: source, sessionNumber: sessionNumber)
    }

    private func refreshSource(
        source: RemoteDataSource,
        sessionNumber: UInt
    ) async {
        AirshipLogger.trace("Attempting to refresh source \(source) sessionNumber \(sessionNumber)")
        if await self.remoteData.refresh(source: source) {
            AirshipLogger.trace("Refreshed source \(source) sessionNumber \(sessionNumber)")
            self.lastRefreshState[source] = sessionNumber
        } else {
            AirshipLogger.trace("Failed to refresh source \(source) sessionNumber \(sessionNumber)")
        }
    }
}
