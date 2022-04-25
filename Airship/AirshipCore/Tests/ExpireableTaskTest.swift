/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class ExpireableTaskTest: XCTestCase {

    func testCompletionHandler() throws {
        var taskResult: Bool?
        let task = ExpirableTask(taskID: "some-task", requestOptions: .defaultOptions) { result in
            taskResult = result
        }

        var completedCalled = false
        task.completionHandler = {
            completedCalled = true
        }

        task.taskCompleted()
        XCTAssertTrue(completedCalled)
        XCTAssertTrue(taskResult!)
    }

    func testSetCompletionHandlerAfterComplete() throws {
        var taskResult: Bool?
        let task = ExpirableTask(taskID: "some-task", requestOptions: .defaultOptions) { result in
            taskResult = result
        }

        task.taskFailed()
        XCTAssertFalse(taskResult!)

        var completedCalled = false
        task.completionHandler = {
            completedCalled = true
        }

        XCTAssertTrue(completedCalled)
    }

    func testExpireNoHandler() throws {
        var taskResult: Bool?
        let task = ExpirableTask(taskID: "some-task", requestOptions: .defaultOptions) { result in
            taskResult = result
        }
        task.expire()
        XCTAssertFalse(taskResult!)
    }

    func testExpire() throws {
        var taskResult: Bool?
        let task = ExpirableTask(taskID: "some-task", requestOptions: .defaultOptions) { result in
            taskResult = result
        }

        var expiredCalled = false
        task.expirationHandler = {
            expiredCalled = true
        }
        task.expire()
        XCTAssertTrue(expiredCalled)
        XCTAssertNil(taskResult)
    }

    func testSetExpireHandlerAfterExpired() throws {
        let task = ExpirableTask(taskID: "some-task", requestOptions: .defaultOptions) { _ in }

        task.expire()

        var expiredCalled = false
        task.expirationHandler = {
            expiredCalled = true
        }

        XCTAssertTrue(expiredCalled)
    }

}
