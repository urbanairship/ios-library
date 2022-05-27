/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class PermissionsManagerTests: XCTestCase {

    let permissionsManager = PermissionsManager()
    let delegate = TestPermissionsDelegate()

    func testCheckPermissionNotConfigured() throws {
        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.checkPermissionStatus(.postNotifications) { status in
            XCTAssertEqual(PermissionStatus.notDetermined, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
    }

    func testCheckPermission() throws {
        self.permissionsManager.setDelegate(self.delegate, permission: .appTransparencyTracking)
        self.delegate.permissionStatus = .granted

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.checkPermissionStatus(.appTransparencyTracking) { status in
            XCTAssertEqual(PermissionStatus.granted, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
        XCTAssertTrue(self.delegate.checkCalled)
        XCTAssertFalse(self.delegate.requestCalled)
    }

    func testRequestPermissionNotConfigured() throws {
        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.postNotifications) { status in
            XCTAssertEqual(PermissionStatus.notDetermined, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
    }

    func testRequestPermission() throws {
        self.permissionsManager.setDelegate(self.delegate, permission: .appTransparencyTracking)
        self.delegate.permissionStatus = .denied

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.appTransparencyTracking) { status in
            XCTAssertEqual(PermissionStatus.denied, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
        XCTAssertTrue(self.delegate.requestCalled)
        XCTAssertFalse(self.delegate.checkCalled)
    }

    func testConfiguredPermissionsEmpty() throws {
        XCTAssertTrue(self.permissionsManager.configuredPermissions.isEmpty)
    }

    func testConfiguredPermissions() throws {
        self.permissionsManager.setDelegate(self.delegate, permission: .appTransparencyTracking)
        self.permissionsManager.setDelegate(self.delegate, permission: .bluetooth)

        let expected = Set<Permission>([.appTransparencyTracking, .bluetooth])
        let configured = self.permissionsManager.configuredPermissions
        XCTAssertEqual(expected, configured)
    }

    func testAirshipEnablers() throws {
        self.permissionsManager.setDelegate(self.delegate, permission: .mic)
        self.delegate.permissionStatus = .granted

        let enablerCalled = self.expectation(description: "Enabler called")
        self.permissionsManager.addAirshipEnabler(permission: .mic) {
            enablerCalled.fulfill()
        }

        self.permissionsManager.requestPermission(.mic, enableAirshipUsageOnGrant: true) { _ in }
        wait(for: [enablerCalled], timeout: 1)
    }

    func testRequestExtender() throws {
        self.permissionsManager.setDelegate(self.delegate, permission: .mic)
        self.delegate.permissionStatus = .denied

        let listener1 = self.expectation(description: "Listener 1")
        self.permissionsManager.addRequestExtender(permission: .mic) { status, completion in
            DispatchQueue.main.async {
                listener1.fulfill()
                completion()
            }
        }

        let listener2 = self.expectation(description: "Listener 2")
        self.permissionsManager.addRequestExtender(permission: .mic) { status, completion in
            listener2.fulfill()
            completion()
        }

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.mic) { status in
            XCTAssertEqual(PermissionStatus.denied, status)
            callbackCalled.fulfill()
        }

        wait(for: [listener1, listener2, callbackCalled], timeout: 1, enforceOrder: true)
    }
}

class TestPermissionsDelegate: PermissionDelegate {

    var permissionStatus: PermissionStatus = .notDetermined
    var checkCalled: Bool = false
    var requestCalled: Bool = false

    func checkPermissionStatus(completionHandler: @escaping (PermissionStatus) -> Void) {
        self.checkCalled = true
        completionHandler(permissionStatus)
    }

    func requestPermission(completionHandler: @escaping (PermissionStatus) -> Void) {
        self.requestCalled = true
        completionHandler(permissionStatus)
    }
}
