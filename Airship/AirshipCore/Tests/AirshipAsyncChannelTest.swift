/* Copyright Airship and Contributors */

import Testing

@_spi(AirshipInternal) @testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct AirshipAsyncChannelTest {

    private let channel = AirshipAsyncChannel<Int>()

    @Test
    func testSingleListener() async throws {
        var stream = await channel.makeStream().makeAsyncIterator()

        var sent: [Int] = []
        for i in 0...5 {
            sent.append(i)
            await channel.send(i)
        }

        var received: [Int] = []
        for _ in 0...5 {
            received.append(await stream.next()!)
        }

        #expect(sent == received)
    }

    @Test
    func testMultipleListeners() async throws {
        let streams = [
            await channel.makeStream().makeAsyncIterator(),
            await channel.makeStream().makeAsyncIterator(),
            await channel.makeStream().makeAsyncIterator()
        ]

        var sent: [Int] = []
        for i in 0...5 {
            sent.append(i)
            await channel.send(i)
        }

        for var stream in streams {
            var received: [Int] = []
            for _ in 0...5 {
                received.append(await stream.next()!)
            }
            #expect(sent == received)
        }
    }

    @Test
    func testNonIsolatedDedupingStreamMapped() async throws {
        var updates = channel.makeNonIsolatedDedupingStream(
            initialValue: {
                "1"
            },
            transform: { int in
                "\(int)"
            }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        #expect(first == "1")

        await channel.send(2)
        await channel.send(2)
        await channel.send(2)

        await channel.send(3)
        await channel.send(3)
        await channel.send(4)

        var received: [String] = []
        for _ in 0...2 {
            received.append(await updates.next()!)
        }

        #expect(["2", "3", "4"] == received)
    }

    @Test
    func testNonIsolatedDedupingStream() async throws {
        var updates = channel.makeNonIsolatedDedupingStream(
            initialValue: {
                1
            }
        ).makeAsyncIterator()
        await channel.send(1)

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        #expect(first == 1)

        await channel.send(1)
        await channel.send(1)

        await channel.send(2)
        await channel.send(2)
        await channel.send(3)

        var received: [Int] = []
        for _ in 0...1 {
            received.append(await updates.next()!)
        }

        #expect([2, 3] == received)
    }

    @Test
    func testNonIsolatedStreamMapped() async throws {
        var updates = channel.makeNonIsolatedStream(
            initialValue: {
                "1"
            },
            transform: { int in
                "\(int)"
            }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        #expect(first == "1")

        await channel.send(1)
        await channel.send(2)
        await channel.send(2)

        await channel.send(3)
        await channel.send(4)

        var received: [String] = []
        for _ in 0...4 {
            received.append(await updates.next()!)
        }

        #expect(["1", "2", "2", "3", "4"] == received)
    }

    @Test
    func testNonIsolatedStream() async throws {
        var updates = channel.makeNonIsolatedStream(
            initialValue: { 1 }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        #expect(first == 1)

        await channel.send(1)
        await channel.send(1)
        await channel.send(1)

        await channel.send(2)
        await channel.send(2)
        await channel.send(3)

        var received: [Int] = []
        for _ in 0...5 {
            received.append(await updates.next()!)
        }

        #expect([1, 1, 1, 2, 2, 3] == received)
    }

    @Test
    func testNonIsolatedStreamBufferPolicy() async throws {
        let counter = Counter()
        var updates = channel.makeNonIsolatedStream(
            bufferPolicy: .bufferingNewest(1),
            initialValue: { 0 },
            transform: { value in
                await counter.increment()
                return value
            }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        #expect(await updates.next() == 0)

        for value in 1...4 {
            await channel.send(value)
        }

        // Wait until the transform has processed the sentinel (4) so 1...3
        // have all been yielded into the returned stream while unconsumed.
        while await counter.count < 4 {
            await Task.yield()
        }

        var received: [Int] = []
        while let next = await updates.next(), next != 4 {
            received.append(next)
        }

        // With a bufferingNewest(1) policy, the unconsumed 1 and 2 must
        // have been dropped in favor of newer values.
        #expect(!received.contains(1))
        #expect(!received.contains(2))
    }

    @Test
    func testNonIsolatedDedupingStreamBufferPolicy() async throws {
        let counter = Counter()
        var updates = channel.makeNonIsolatedDedupingStream(
            bufferPolicy: .bufferingNewest(1),
            initialValue: { 0 },
            transform: { value in
                await counter.increment()
                return value
            }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        #expect(await updates.next() == 0)

        for value in 1...4 {
            await channel.send(value)
        }

        // Wait until the transform has processed the sentinel (4) so 1...3
        // have all been yielded into the returned stream while unconsumed.
        while await counter.count < 4 {
            await Task.yield()
        }

        var received: [Int] = []
        while let next = await updates.next(), next != 4 {
            received.append(next)
        }

        // With a bufferingNewest(1) policy, the unconsumed 1 and 2 must
        // have been dropped in favor of newer values.
        #expect(!received.contains(1))
        #expect(!received.contains(2))
    }

}

fileprivate actor Counter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
