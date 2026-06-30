/* Copyright Airship and Contributors */

import Testing

@testable public import AirshipCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PermissionsManagerTests {

    let delegate: TestPermissionsDelegate

    let systemSettingsNavigator: TestSystemSettingsNavigator
    let permissionsManager: DefaultAirshipPermissionsManager
    let appStateTracker = TestAppStateTracker()

    init() {
        self.systemSettingsNavigator = TestSystemSettingsNavigator()
        permissionsManager = DefaultAirshipPermissionsManager(
            appStateTracker: appStateTracker,
            systemSettingsNavigator: systemSettingsNavigator
        )
        self.delegate = TestPermissionsDelegate()
    }

    @Test
    func testCheckPermissionNotConfigured() async throws {
        let status = await self.permissionsManager.checkPermissionStatus(.displayNotifications)
        
        #expect(AirshipPermissionStatus.notDetermined == status)
    }

    @Test
    @MainActor
    func testCheckPermission() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .granted

        let status = await self.permissionsManager.checkPermissionStatus(.location)

        #expect(AirshipPermissionStatus.granted == status)
        #expect(self.delegate.checkCalled)
        #expect(!(self.delegate.requestCalled))
    }

    @Test
    @MainActor
    func testStatusUpdate() async {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        var stream = self.permissionsManager.statusUpdate(for: .location).makeAsyncIterator()
        let status = await self.permissionsManager.requestPermission(.location)

        let currentStatus = await stream.next()
        #expect(AirshipPermissionStatus.denied == status)
        #expect(status == currentStatus)
    }

    @Test
    @MainActor
    func testStatusRefreshOnActive() async {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        var stream = self.permissionsManager.statusUpdate(for: .location).makeAsyncIterator()

        var currentStatus = await stream.next()
        #expect(AirshipPermissionStatus.denied == currentStatus)

        self.delegate.permissionStatus = .granted

        await self.appStateTracker.updateState(.active)

        currentStatus = await stream.next()
        #expect(AirshipPermissionStatus.granted == currentStatus)
    }

    @Test
    func testRequestPermissionNotConfigured() async throws {
        let status = await self.permissionsManager.requestPermission(.displayNotifications)

        #expect(AirshipPermissionStatus.notDetermined == status)
    }

    @Test
    @MainActor
    func testRequestPermissionNotDetermined() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .notDetermined

        let status = await self.permissionsManager.requestPermission(.location)

        #expect(AirshipPermissionStatus.notDetermined == status)
        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
    }

    @Test
    @MainActor
    func testRequestPermissionDenied() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let status = await self.permissionsManager.requestPermission(.location)

        #expect(AirshipPermissionStatus.denied == status)
        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
    }

    @Test
    @MainActor
    func testRequestPermissionGranted() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .granted

        let status = await self.permissionsManager.requestPermission(.location)

        #expect(AirshipPermissionStatus.granted == status)
        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
    }

    @Test
    @MainActor
    func testRequestPermissionSystemSettingsFallback() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        _ = await self.permissionsManager.requestPermission(.location, enableAirshipUsageOnGrant: false, fallback: .systemSettings)

        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
        #expect(systemSettingsNavigator.permissionOpens == [.location])
    }

    @Test
    @MainActor
    func testRequestPermissionSystemSettingsFallbackFailsToOpen() async throws {
        self.systemSettingsNavigator.permissionOpenResult = false

        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        _ = await self.permissionsManager.requestPermission(.location, enableAirshipUsageOnGrant: false, fallback: .systemSettings)

        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
        #expect(systemSettingsNavigator.permissionOpens == [.location])
    }

    @Test
    @MainActor
    func testRequestPermissionCallbackFallback() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let status = await self.permissionsManager.requestPermission(
            .location,
            enableAirshipUsageOnGrant: false,
            fallback: .callback({
                self.delegate.permissionStatus = .granted
            })
        )

        #expect(AirshipPermissionStatus.granted == status.endStatus)
        #expect(self.delegate.requestCalled)
        #expect(self.delegate.checkCalled)
    }

    @Test
    func testConfiguredPermissionsEmpty() throws {
        #expect(self.permissionsManager.configuredPermissions.isEmpty)
    }

    @Test
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
        #expect(expected == configured)
    }

    @Test
    @MainActor
    func testAirshipEnablers() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .displayNotifications
        )
        self.delegate.permissionStatus = .granted

        let enablerCalled = AirshipTestExpectation(description: "Enabler called")
        self.permissionsManager.addAirshipEnabler(
            permission: .displayNotifications
        ) {
            enablerCalled.fulfill()
        }

        let _ = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        await fulfillment(of: [enablerCalled], timeout: 1)
    }

    @Test
    @MainActor
    func testRequestExtender() async throws {
        self.permissionsManager.setDelegate(
            self.delegate,
            permission: .location
        )
        self.delegate.permissionStatus = .denied

        let listener1 = AirshipTestExpectation(description: "Listener 1")
        self.permissionsManager.addRequestExtender(permission: .location) { status in
            listener1.fulfill()
        }

        let listener2 = AirshipTestExpectation(description: "Listener 2")
        self.permissionsManager.addRequestExtender(permission: .location) { status in
            listener2.fulfill()
        }

        let status = await self.permissionsManager.requestPermission(.location) 

        #expect(AirshipPermissionStatus.denied == status)
        await fulfillment(
            of: [listener1, listener2],
            timeout: 1
        )
    }
}

@MainActor
final class TestPermissionsDelegate: AirshipPermissionDelegate {

    public var permissionStatus: AirshipPermissionStatus = .notDetermined
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


@MainActor
public final class TestSystemSettingsNavigator: SystemSettingsNavigatorProtocol {
    var permissionOpens: [AirshipPermission] =  []
    var permissionOpenResult = false
    public func open(for permission: AirshipPermission) async -> Bool {
        permissionOpens.append(permission)
        return permissionOpenResult
    }
    

}
