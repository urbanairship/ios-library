/* Copyright Airship and Contributors */



/// AsyncSequence of `LiveActivityRegistrationStatus` updates.
public struct LiveActivityRegistrationStatusUpdates: AsyncSequence {
    public typealias Element = LiveActivityRegistrationStatus

    private let statusProducer: @Sendable (LiveActivityRegistrationStatus?) async -> LiveActivityRegistrationStatus?

    init(statusProducer: @escaping @Sendable (LiveActivityRegistrationStatus?) async -> LiveActivityRegistrationStatus?) {
        self.statusProducer = statusProducer
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let statusProducer: @Sendable (LiveActivityRegistrationStatus?) async -> LiveActivityRegistrationStatus?
        private var lastStatus: LiveActivityRegistrationStatus?

        init(statusProducer: @escaping @Sendable (LiveActivityRegistrationStatus?) async -> LiveActivityRegistrationStatus?) {
            self.statusProducer = statusProducer
        }

        public mutating func next() async -> Element? {
            let status = await statusProducer(lastStatus)
            self.lastStatus = status
            return status
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(statusProducer: statusProducer)
    }
}
