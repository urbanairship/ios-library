/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class PermissionsManagerTests: XCTestCase {

    let notificationCenter = NotificationCenter()
    var permissionsManager: AirshipPermissionsManager!
    let delegate = TestPermissionsDelegate()

    override func setUp() async throws {
        permissionsManager = AirshipPermissionsManager(notificationCenter: notificationCenter)
    }
    func testCheckPermissionNotConfigured() async throws {
        let status = await self.permissionsManager.checkPermissionStatus(.displayNotifications)
        
        XCTAssertEqual(AirshipPermissionStatus.notDetermined, status)
    }

    func testCheckPermission() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .granted

        let status = await self.permissionsManager.checkPermissionStatus(.location)

        XCTAssertEqual(AirshipPermissionStatus.granted, status)
        XCTAssertTrue(self.delegate.checkCalled)
        XCTAssertFalse(self.delegate.requestCalled)
    }
    
    func testStatusUpdate() async {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        var stream = self.permissionsManager.statusUpdate(for: .location).makeAsyncIterator()
        let status = await self.permissionsManager.requestPermission(.location)

        let currentStatus = await stream.next()
        XCTAssertEqual(AirshipPermissionStatus.denied, status)
        XCTAssertEqual(status, currentStatus)
    }
    
    func testStatusRefreshOnActive() async {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        var stream = self.permissionsManager.statusUpdate(for: .location).makeAsyncIterator()

        var currentStatus = await stream.next()
        XCTAssertEqual(AirshipPermissionStatus.denied, currentStatus)

        self.delegate.permissionStatus = .granted
        
        Task { @MainActor in
            notificationCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        }

        currentStatus = await stream.next()
        XCTAssertEqual(AirshipPermissionStatus.granted, currentStatus)
    }

    func testRequestPermissionNotConfigured() async throws {
        let status = await self.permissionsManager.requestPermission(.displayNotifications)

        XCTAssertEqual(AirshipPermissionStatus.notDetermined, status)
    }

    func testRequestPermission() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let status = await self.permissionsManager.requestPermission(.location)

        XCTAssertEqual(AirshipPermissionStatus.denied, status)
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

    func testAirshipEnablers() async throws {
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

        let _ = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        await self.fulfillmentCompat(of: [enablerCalled], timeout: 1)
    }

    func testRequestExtender() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let listener1 = self.expectation(description: "Listener 1")
        self.permissionsManager.addRequestExtender(permission: .location) { status in
            listener1.fulfill()
        }

        let listener2 = self.expectation(description: "Listener 2")
        self.permissionsManager.addRequestExtender(permission: .location) { status in
            listener2.fulfill()
        }

        let status = await self.permissionsManager.requestPermission(.location) 

        XCTAssertEqual(AirshipPermissionStatus.denied, status)
        await self.fulfillmentCompat(
            of: [listener1, listener2],
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

    public func checkPermissionStatus() async -> AirshipPermissionStatus {
        self.checkCalled = true
        return permissionStatus
    }

    public func requestPermission() async -> AirshipPermissionStatus {
        self.requestCalled = true
       return permissionStatus
    }
}
