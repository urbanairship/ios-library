/* Copyright Airship and Contributors */

import Foundation


// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataAutomationAccess)
public final class _RemoteDataAutomationAccess: NSObject {
    private let remoteData: RemoteDataProtocol
    private let network: NetworkCheckerProtocol

    init(
        remoteData: RemoteDataProtocol,
        network: NetworkCheckerProtocol = NetworkChecker()
    ) {
        self.remoteData = remoteData
        self.network = network
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
        guard let remoteDataInfo = remoteDataInfo else {
            return false
        }
        return await remoteData.isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func requiresUpdate(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        guard await isCurrent(remoteDataInfo: remoteDataInfo) else {
            return true
        }

        let source = remoteDataInfo?.source ?? .app
        switch(await remoteData.status(source: source)) {
        case .outOfDate:
            return true
        case .stale:
            return false
        case .upToDate:
            return false
        }
    }

    @objc
    public func waitFullRefresh(remoteDataInfo: RemoteDataInfo?) async {
        let source = remoteDataInfo?.source ?? .app
        await self.remoteData.waitRefresh(source: source)
    }

    @objc
    public func bestEffortRefresh(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        let source = remoteDataInfo?.source ?? .app
        guard await isCurrent(remoteDataInfo: remoteDataInfo) else {
            return false
        }

        if await self.remoteData.status(source: source) == .upToDate {
            return true
        }

        // if we are connected wait for refresh
        if (await network.isConnected) {
            await remoteData.waitRefreshAttempt(source: source)
        }

        return await isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func notifyOutdated(remoteDataInfo: RemoteDataInfo?) async {
        if let remoteDataInfo = remoteDataInfo {
            await self.remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        }
    }
}
