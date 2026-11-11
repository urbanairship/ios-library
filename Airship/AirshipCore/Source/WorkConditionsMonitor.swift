/* Copyright Airship and Contributors */

import Combine
@_spi(AirshipInternal) import AirshipBasement
import Foundation

struct WorkConditionsMonitor: @unchecked Sendable {
    private let cancellable: AnyCancellable
    private let conditionsSubject: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
    private let networkMonitor: any AirshipNetworkCheckerProtocol

    init(
        networkMonitor: any AirshipNetworkCheckerProtocol = AirshipNetworkChecker()
    ) {
        self.networkMonitor = networkMonitor
        self.cancellable = Publishers.CombineLatest(
            NotificationCenter.default.publisher(
                for: AppStateTracker.didBecomeActiveNotification
            ),
            NotificationCenter.default.publisher(
                for: AppStateTracker.didEnterBackgroundNotification
            )
        )
        .receive(on: RunLoop.main)
        .sink { [conditionsSubject] _ in
            conditionsSubject.send()
        }

        Task { @MainActor [conditionsSubject] in
            for await _ in networkMonitor.connectionUpdates {
                conditionsSubject.send()
            }
        }
    }

    @MainActor
    func checkConditions(workRequest: AirshipWorkRequest) -> Bool {
        if workRequest.requiresNetwork == true {
            return networkMonitor.isConnected
        }

        return true
    }

    @MainActor
    private final class ConditionsWaiter {
        var continuation: CheckedContinuation<Void, Never>?
        var cancellable: AnyCancellable?

        func resume() {
            cancellable?.cancel()
            cancellable = nil
            continuation?.resume()
            continuation = nil
        }
    }

    @MainActor
    private func waitConditionsUpdate() async {
        let waiter = ConditionsWaiter()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // onCancel ran before the continuation existed, so nothing would resume it.
                guard !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                waiter.continuation = continuation
                waiter.cancellable = self.conditionsSubject
                    .first()
                    .sink { _ in waiter.resume() }
            }
        } onCancel: {
            Task { @MainActor in waiter.resume() }
        }
    }

    /// Suspends until the request's conditions are met.
    /// - Parameter workRequest: The request whose conditions to wait on.
    /// - Throws: `CancellationError` if the calling task is cancelled while waiting.
    @MainActor
    func awaitConditions(workRequest: AirshipWorkRequest) async throws {
        while checkConditions(workRequest: workRequest) == false {
            try Task.checkCancellation()
            await waitConditionsUpdate()
        }
        try Task.checkCancellation()
    }
}
