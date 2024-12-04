/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class AirshipAsyncChannelTest: XCTestCase {

    private let channel = AirshipAsyncChannel<Int>()

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

        XCTAssertEqual(sent, received)
    }

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
            XCTAssertEqual(sent, received)
        }
    }

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
        XCTAssertEqual(first, "1")

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

        XCTAssertEqual(["2", "3", "4"], received)
    }

    func testNonIsolatedDedupingStream() async throws {
        var updates = channel.makeNonIsolatedDedupingStream(
            initialValue: {
                1
            }
        ).makeAsyncIterator()
        await channel.send(1)

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        XCTAssertEqual(first, 1)

        await channel.send(1)
        await channel.send(1)

        await channel.send(2)
        await channel.send(2)
        await channel.send(3)

        var received: [Int] = []
        for _ in 0...1 {
            received.append(await updates.next()!)
        }

        XCTAssertEqual([2, 3], received)
    }

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
        XCTAssertEqual(first, "1")

        await channel.send(1)
        await channel.send(2)
        await channel.send(2)

        await channel.send(3)
        await channel.send(4)

        var received: [String] = []
        for _ in 0...4 {
            received.append(await updates.next()!)
        }

        XCTAssertEqual(["1", "2", "2", "3", "4"], received)
    }

    func testNonIsolatedStream() async throws {
        var updates = channel.makeNonIsolatedStream(
            initialValue: { 1 }
        ).makeAsyncIterator()

        // Wait for first so we know the task is setup to listen for changes
        let first = await updates.next()
        XCTAssertEqual(first, 1)

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

        XCTAssertEqual([1, 1, 1, 2, 2, 3], received)
    }

}
