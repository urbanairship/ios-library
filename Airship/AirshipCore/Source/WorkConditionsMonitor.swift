import Combine

struct WorkConditionsMonitor {
    private var cancellables = Set<AnyCancellable>()
    private let conditionsSubject = PassthroughSubject<Void, Never>()
    private let backgroundTime: WorkBackgroundTimeProtocol
    private let networkMonitor: NetworkMonitor

    init(
        backgroundTime: WorkBackgroundTimeProtocol = WorkBackgroundTime(),
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.backgroundTime = backgroundTime
        self.networkMonitor = networkMonitor

        Publishers.CombineLatest(
            NotificationCenter.default.publisher(
                for: AppStateTracker.didBecomeActiveNotification
            ),
            NotificationCenter.default.publisher(
                for: AppStateTracker.didEnterBackgroundNotification
            )
        )
        .sink { [conditionsSubject] _ in
            conditionsSubject.send()
        }
        .store(in: &self.cancellables)

        networkMonitor.connectionUpdates = { [conditionsSubject] _ in
            conditionsSubject.send()
        }
    }

    @MainActor
    private var timeRemaining: TimeInterval {
        return backgroundTime.remainingTime
    }

    @MainActor
    func checkConditions(workRequest: AirshipWorkRequest) -> Bool {
        guard timeRemaining >= 60.0 else { return false }

        if workRequest.requiresNetwork == true {
            return networkMonitor.isConnected
        }

        return true
    }

    @MainActor
    private func waitConditionsUpdate() async {
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable? = nil
            cancellable = self.conditionsSubject
                .first()
                .sink { _ in
                    continuation.resume()
                    cancellable?.cancel()
                }
        }
    }

    @MainActor
    func awaitConditions(workRequest: AirshipWorkRequest) async {
        while checkConditions(workRequest: workRequest) == false {
            await waitConditionsUpdate()
        }
    }
}
