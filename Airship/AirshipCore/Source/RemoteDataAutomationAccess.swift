/* Copyright Airship and Contributors */

import Foundation


@objc(UARemoteDataAutomationAccess)
public final class _RemoteDataAutomationAccess: NSObject {
    private let remoteData: RemoteDataProtocol
    private let networkMonitor: NetworkMonitor = NetworkMonitor()

    init(remoteData: RemoteDataProtocol) {
        self.remoteData = remoteData
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
    public func refreshAndCheckCurrent(remoteDataInfo: RemoteDataInfo?) async -> Bool {
        if (networkMonitor.isConnected) {
            await remoteData.refresh(source: remoteDataInfo?.source ?? .app)
        }

        return await isCurrent(remoteDataInfo: remoteDataInfo)
    }

    @objc
    public func refreshOutdated(remoteDataInfo: RemoteDataInfo?) async {
        if let remoteDataInfo = remoteDataInfo {
            await remoteData.notifyOutdated(remoteDataInfo: remoteDataInfo)
        }

        await remoteData.refresh(source: remoteDataInfo?.source ?? .app)
    }
}
