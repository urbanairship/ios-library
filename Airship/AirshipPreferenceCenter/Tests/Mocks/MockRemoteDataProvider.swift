
@testable
import AirshipCore
import Foundation
import Combine


final class MockRemoteDataProvider: RemoteDataProtocol, @unchecked Sendable {
    let updatesSubject = PassthroughSubject<[RemoteDataPayload], Never>()
    var isCurrent = true
    var payloads: [RemoteDataPayload] = [] {
        didSet {
            updatesSubject.send(payloads)
        }
    }

    var remoteDataRefreshInterval: TimeInterval = 0
    var isContactSourceEnabled: Bool = false
    func setContactSourceEnabled(enabled: Bool) {
        isContactSourceEnabled = enabled
    }

    func isCurrent(remoteDataInfo: RemoteDataInfo) async -> Bool {
        return isCurrent
    }

    func notifyOutdated(remoteDataInfo: AirshipCore.RemoteDataInfo) async {

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

    func refresh() async -> Bool {
        return true
    }

    func refresh(source: AirshipCore.RemoteDataSource) async -> Bool {
        return true
    }
}

