/* Copyright Airship and Contributors */

@preconcurrency
import Combine
import SwiftUI

protocol AirshipEmbeddedViewManagerProtocol: Sendable {
    @MainActor
    func addPending(
        presentation: ThomasPresentationInfo.Embedded,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: any ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int
    ) -> any AirshipMainActorCancellable

    var publisher: AnyPublisher<[PendingEmbedded], Never> { get }
    func publisher(embeddedViewID: String) -> AnyPublisher<[PendingEmbedded], Never>
}

final class AirshipEmbeddedViewManager: AirshipEmbeddedViewManagerProtocol {

    public static let shared = AirshipEmbeddedViewManager()

    @MainActor
    private var pending: [PendingEmbedded] = []
    private let viewSubject = CurrentValueSubject<[PendingEmbedded], Never>([])

    var publisher: AnyPublisher<[PendingEmbedded], Never> {
        viewSubject.eraseToAnyPublisher()
    }

    @MainActor
    func addPending(
        presentation: ThomasPresentationInfo.Embedded,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: any ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int
    ) -> any AirshipMainActorCancellable {
        let id = UUID().uuidString

        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions) {
            self.pending.removeAll { $0.id == id }
            self.viewSubject.send(self.pending)
        }

        self.pending.append(
            PendingEmbedded(
                id: id,
                presentation: presentation,
                layout: layout,
                environment: environment,
                embeddedInfo: AirshipEmbeddedInfo(
                    instanceID: id,
                    embeddedID: presentation.embeddedID,
                    extras: extras,
                    priority: priority
                )
            )
        )

        self.viewSubject.send(self.pending)

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    func publisher(embeddedViewID: String) -> AnyPublisher<[PendingEmbedded], Never> {
        return viewSubject
            .map { array in
                array.filter { value in value.presentation.embeddedID == embeddedViewID }
            }
            .eraseToAnyPublisher()
    }
}

struct PendingEmbedded: Sendable {
    fileprivate let id: String
    let presentation: ThomasPresentationInfo.Embedded
    let layout: AirshipLayout
    let environment: ThomasEnvironment
    let embeddedInfo: AirshipEmbeddedInfo
}


