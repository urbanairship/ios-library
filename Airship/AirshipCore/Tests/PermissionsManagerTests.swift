/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class PermissionsManagerTests: XCTestCase {

    let permissionsManager = AirshipPermissionsManager()
    let delegate = TestPermissionsDelegate()

    func testCheckPermissionNotConfigured() throws {
        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.checkPermissionStatus(.displayNotifications) {
            status in
            XCTAssertEqual(AirshipPermissionStatus.notDetermined, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
    }

    func testCheckPermission() throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .granted

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.checkPermissionStatus(.location) { status in
            XCTAssertEqual(AirshipPermissionStatus.granted, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
        XCTAssertTrue(self.delegate.checkCalled)
        XCTAssertFalse(self.delegate.requestCalled)
    }

    func testRequestPermissionNotConfigured() throws {
        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.displayNotifications) {
            status in
            XCTAssertEqual(AirshipPermissionStatus.notDetermined, status)
            callbackCalled.fulfill()
        }

        wait(for: [callbackCalled], timeout: 1)
    }

    func testRequestPermission() throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.location) { status in
            XCTAssertEqual(AirshipPermissionStatus.denied, status)
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
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .displayNotifications
        )

        let expected = Set<AirshipPermission>([.location, .displayNotifications])
        let configured = self.permissionsManager.configuredPermissions
        XCTAssertEqual(expected, configured)
    }

    func testAirshipEnablers() throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .displayNotifications
        )
        self.delegate.permissionStatus = .granted

        let enablerCalled = self.expectation(description: "Enabler called")
        self.permissionsManager.addAirshipEnabler(
            permission: .displayNotifications
        ) {
            enablerCalled.fulfill()
        }

        self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        ) { _ in }
        wait(for: [enablerCalled], timeout: 1)
    }

    func testRequestExtender() throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let listener1 = self.expectation(description: "Listener 1")
        self.permissionsManager.addRequestExtender(permission: .location) {
            status,
            completion in
            DispatchQueue.main.async {
                listener1.fulfill()
                completion()
            }
        }

        let listener2 = self.expectation(description: "Listener 2")
        self.permissionsManager.addRequestExtender(permission: .location) {
            status,
            completion in
            listener2.fulfill()
            completion()
        }

        let callbackCalled = self.expectation(description: "Callback called")
        self.permissionsManager.requestPermission(.location) { status in
            XCTAssertEqual(AirshipPermissionStatus.denied, status)
            callbackCalled.fulfill()
        }

        wait(
            for: [listener1, listener2, callbackCalled],
            timeout: 1,
            enforceOrder: true
        )
    }
}

@objc
open class TestPermissionsDelegate: NSObject, AirshipPermissionDelegate {

    @objc public var permissionStatus: AirshipPermissionStatus = .notDetermined
    var checkCalled: Bool = false
    var requestCalled: Bool = false

    public func checkPermissionStatus(
        completionHandler: @escaping (AirshipPermissionStatus) -> Void
    ) {
        self.checkCalled = true
        completionHandler(permissionStatus)
    }

    public func requestPermission(
        completionHandler: @escaping (AirshipPermissionStatus) -> Void
    ) {
        self.requestCalled = true
        completionHandler(permissionStatus)
    }
}
