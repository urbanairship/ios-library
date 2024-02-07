/* Copyright Airship and Contributors */

import Combine
import SwiftUI

protocol AirshipEmbeddedViewManagerProtocol {
    @MainActor
    func addPending(
        presentation: EmbeddedPresentationModel,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) -> AirshipMainActorCancellable

    func publisher(embeddedViewID: String) -> AnyPublisher<[PendingEmbedded], Never>
}

final class AirshipEmbeddedViewManager: AirshipEmbeddedViewManagerProtocol {
    public static let shared = AirshipEmbeddedViewManager()

    private var pending: [PendingEmbedded] = []
    private let viewSubject = CurrentValueSubject<[PendingEmbedded], Never>([])


    @MainActor
    func addPending(
        presentation: EmbeddedPresentationModel,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) -> AirshipMainActorCancellable {
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
                environment: environment
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

struct PendingEmbedded {
    fileprivate let id: String
    let presentation: EmbeddedPresentationModel
    let layout: AirshipLayout
    let environment: ThomasEnvironment
}
