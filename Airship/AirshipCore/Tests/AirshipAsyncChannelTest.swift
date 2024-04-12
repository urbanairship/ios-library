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

}
