/* Copyright Airship and Contributors */

@preconcurrency
public import Combine
import SwiftUI
@_spi(AirshipInternal) public import AirshipBasement

@_spi(AirshipInternal)
public protocol AirshipEmbeddedViewManagerProtocol: Sendable {
    @MainActor
    func addPending(
        presentation: ThomasPresentationInfo.Embedded,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int,
        extensions: any ThomasExtensions
    ) -> any AirshipMainActorCancellable

    var publisher: AnyPublisher<[PendingEmbedded], Never> { get }
    func publisher(embeddedViewID: String) -> AnyPublisher<[PendingEmbedded], Never>

    @MainActor
    var embeddedAISelector: (any EmbeddedAISelector)? { get }
}

@_spi(AirshipInternal)
public final class AirshipEmbeddedViewManager: AirshipEmbeddedViewManagerProtocol {

    public static let shared: AirshipEmbeddedViewManager = AirshipEmbeddedViewManager()

    /// AI selector for `.ai` embedded selection. Injected once at SDK setup (by the module that
    /// owns the AI manager); nil when AI isn't available, in which case `.ai` selection falls
    /// back. Lives here — external to per-layout `ThomasExtensions` — because choosing which
    /// pending embedded to show is an embedded-view concern, not a layout-render one.
    @MainActor
    public var embeddedAISelector: (any EmbeddedAISelector)? = nil

    @MainActor
    private var pending: [PendingEmbedded] = []
    private let viewSubject: CurrentValueSubject<[PendingEmbedded], Never> = CurrentValueSubject<[PendingEmbedded], Never>([])

    public var publisher: AnyPublisher<[PendingEmbedded], Never> {
        viewSubject.eraseToAnyPublisher()
    }

    @MainActor
    public func addPending(
        presentation: ThomasPresentationInfo.Embedded,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int,
        extensions: any ThomasExtensions
    ) -> any AirshipMainActorCancellable {
        let id = UUID().uuidString

        let dismissHandle = ThomasDismissHandle()

        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions, dismissHandle: dismissHandle) {
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
                ),
                dismissHandle: dismissHandle
            )
        )

        self.viewSubject.send(self.pending)

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    public func publisher(embeddedViewID: String) -> AnyPublisher<[PendingEmbedded], Never> {
        return viewSubject
            .map { array in
                array.filter { value in value.presentation.embeddedID == embeddedViewID }
            }
            .eraseToAnyPublisher()
    }
}

@_spi(AirshipInternal)
public struct PendingEmbedded: Sendable {
    fileprivate let id: String
    let presentation: ThomasPresentationInfo.Embedded
    let layout: AirshipLayout
    let environment: ThomasEnvironment
    let embeddedInfo: AirshipEmbeddedInfo
    let dismissHandle: ThomasDismissHandle
}


