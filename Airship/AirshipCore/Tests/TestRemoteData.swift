
@testable
import AirshipCore

import Combine


final class TestRemoteData: NSObject, RemoteDataProtocol, @unchecked Sendable {
    func statusUpdates<T>(sources: [AirshipCore.RemoteDataSource], map: @escaping (@Sendable ([AirshipCore.RemoteDataSource : AirshipCore.RemoteDataSourceStatus]) -> T)) -> AsyncStream<T> where T : Sendable {
        return AsyncStream<T> { _ in }
    }
    
    func forceRefresh() async {
    }

    var waitForRefreshAttemptBlock: ((RemoteDataSource, TimeInterval?) -> Void)?
    var waitForRefreshBlock: ((RemoteDataSource, TimeInterval?) -> Void)?

    var notifiedOutdatedInfos: [RemoteDataInfo] = []

    let updatesSubject = PassthroughSubject<[RemoteDataPayload], Never>()
    var isCurrent = true
    var payloads: [RemoteDataPayload] = [] {
        didSet {
            updatesSubject.send(payloads)
        }
    }

    var status: [RemoteDataSource : RemoteDataSourceStatus] = [:]


    var remoteDataRefreshInterval: TimeInterval = 0
    var isContactSourceEnabled: Bool = false
    func setContactSourceEnabled(enabled: Bool) {
        isContactSourceEnabled = enabled
    }


    func isCurrent(remoteDataInfo: RemoteDataInfo) async -> Bool {
        return isCurrent
    }

    func notifyOutdated(remoteDataInfo: RemoteDataInfo) async {
        self.notifiedOutdatedInfos.append(remoteDataInfo)
    }

    func status(source: RemoteDataSource) async -> RemoteDataSourceStatus {
        return self.status[source] ?? .outOfDate
    }

    func publisher(types: [String]) -> AnyPublisher<[RemoteDataPayload], Never> {
        updatesSubject
            .prepend(payloads)
            .map{ payloads in
                return payloads.filter { payload in
                    types.contains(payload.type)
                }
                .sorted { first, second in
                    let firstIndex = types.firstIndex(of: first.type) ?? 0
                    let secondIndex = types.firstIndex(of: second.type) ?? 0
                    return firstIndex < secondIndex
                }
            }
            .eraseToAnyPublisher()
    }

    func payloads(types: [String]) async -> [RemoteDataPayload] {
        return payloads.filter { payload in
            types.contains(payload.type)
        }
        .sorted { first, second in
            let firstIndex = types.firstIndex(of: first.type) ?? 0
            let secondIndex = types.firstIndex(of: second.type) ?? 0
            return firstIndex < secondIndex
        }
    }


    func waitRefresh(
        source: AirshipCore.RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        self.waitForRefreshBlock?(source, maxTime)
    }

    func waitRefreshAttempt(
        source: AirshipCore.RemoteDataSource,
        maxTime: TimeInterval?
    ) async {
        self.waitForRefreshAttemptBlock?(source, maxTime)
    }

    func waitRefresh(source: AirshipCore.RemoteDataSource) async {
        await self.waitRefresh(source: source, maxTime: nil)
    }

    func waitRefreshAttempt(source: AirshipCore.RemoteDataSource) async {
        await self.waitRefreshAttempt(source: source, maxTime: nil)
    }

}

