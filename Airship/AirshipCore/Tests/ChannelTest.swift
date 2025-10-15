/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct ChannelTest {
    let channelRegistrar: TestChannelRegistrar
    let localeManager: TestLocaleManager
    let audienceManager: TestChannelAudienceManager
    let appStateTracker: TestAppStateTracker
    let notificationCenter: AirshipNotificationCenter
    let dataStore: PreferenceDataStore
    let config: AirshipConfig
    let privacyManager: TestPrivacyManager
    let permissionsManager: DefaultAirshipPermissionsManager
    let channel: DefaultAirshipChannel

    // Helper to wait for async conditions with timeout
    private func waitForCondition(
        timeout: Duration = .seconds(2),
        pollingInterval: Duration = .milliseconds(10),
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: pollingInterval)
        }
        throw NSError(domain: "TestTimeout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Condition not met within timeout"])
    }

    init() async throws {
        self.channelRegistrar = TestChannelRegistrar()
        self.localeManager = TestLocaleManager()
        self.audienceManager = TestChannelAudienceManager()
        self.appStateTracker = TestAppStateTracker()
        self.notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.config = AirshipConfig()
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: RuntimeConfig.testConfig(),
            defaultEnabledFeatures: [],
            notificationCenter: self.notificationCenter
        )
        self.permissionsManager = await DefaultAirshipPermissionsManager()
        self.channel = await Self.createChannel(
            dataStore: self.dataStore,
            config: self.config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
    }

    @MainActor
    private static func createChannel(
        dataStore: PreferenceDataStore,
        config: AirshipConfig,
        privacyManager: TestPrivacyManager,
        permissionsManager: DefaultAirshipPermissionsManager,
        localeManager: TestLocaleManager,
        audienceManager: TestChannelAudienceManager,
        channelRegistrar: TestChannelRegistrar,
        notificationCenter: AirshipNotificationCenter,
        appStateTracker: TestAppStateTracker
    ) -> DefaultAirshipChannel {
        return DefaultAirshipChannel(
            dataStore: dataStore,
            config: RuntimeConfig.testConfig(airshipConfig: config),
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            localeManager: localeManager,
            audienceManager: audienceManager,
            channelRegistrar: channelRegistrar,
            notificationCenter: notificationCenter,
            appStateTracker: appStateTracker
        )
    }

    @Test("Registration feature enabled")
    @MainActor
    func registrationFeatureEnabled() async throws {
        #expect(!self.channelRegistrar.registerCalled)
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        // Allow notification to propagate to observers
        try await Task.sleep(for: .milliseconds(100))
        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Tags")
    func tags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channelRegistrar.registerCalled = false
        self.channel.tags = ["foo", "bar"]

        #expect(self.channel.tags == ["foo", "bar"])
        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Edit tags")
    func editTags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channelRegistrar.registerCalled = false

        self.channel.editTags { editor in
            editor.add(["foo", "bar"])
            editor.remove(["foo"])
            editor.add(["baz"])
        }

        #expect(self.channel.tags == ["bar", "baz"])
        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Tags disabled")
    func tagsDisabled() throws {
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        self.channelRegistrar.registerCalled = false

        self.channel.tags = ["neat"]
        self.channel.editTags { editor in
            editor.add(["foo", "bar"])
        }

        #expect(self.channel.tags == [])
        #expect(!self.channelRegistrar.registerCalled)
    }

    @Test("Clear tags privacy manager disabled")
    func clearTagsPrivacyManagerDisabled() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.channel.tags = ["neat"]
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        #expect(self.channel.tags == [])
    }

    @Test("Normalize tags")
    func normalizeTags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channel.tags = [
            "함",
            "함수 목록",
            " neat ",
            "1",
            "  ",
            "",
            String(repeating: "함", count: 128),
            String(repeating: "g", count: 128),
            String(repeating: "b", count: 129),
        ]

        let expected = [
            "함",
            "함수 목록",
            "neat",
            "1",
            String(repeating: "함", count: 128),
            String(repeating: "g", count: 128),
        ]

        #expect(self.channel.tags == expected)
    }

    @Test("Channel creation flag disabled")
    @MainActor
    func channelCreationFlagDisabled() async throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        var config = self.config
        config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        _ = Self.createChannel(
            dataStore: self.dataStore,
            config: config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
        #expect(!self.channelRegistrar.registerCalled)
    }

    @Test("Enable channel creation")
    func enableChannelCreation() async throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        var config = self.config
        config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        let channel = await Self.createChannel(
            dataStore: self.dataStore,
            config: config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
        channel.enableChannelCreation()
        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("CRA payload")
    @MainActor
    func craPayload() async throws {
        self.privacyManager.enableFeatures(.all)

        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted

        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied

        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
        Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.region?.identifier
        expectedPayload.channel.timeZone =
        TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = ["foo", "bar"]
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = [
            "location": "granted",
            "display_notifications": "denied"
        ]

        await MainActor.run { [expectedPayload] in
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return expectedPayload
            }
        }

        let payload = await self.channelRegistrar.channelPayload
        #expect(expectedPayload == payload)
    }

    @Test("CRA payload permission on no feature")
    @MainActor
    func craPayloadPermissionOnNoFeature() async throws {
        self.privacyManager.enableFeatures(.all)
        self.privacyManager.disableFeatures(.tagsAndAttributes)

        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted

        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied

        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
        Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.region?.identifier
        expectedPayload.channel.timeZone =
        TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = []
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = nil

        await MainActor.run { [expectedPayload] in
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return expectedPayload
            }
        }

        let payload = await self.channelRegistrar.channelPayload
        #expect(expectedPayload == payload)
    }

    @Test("CRA payload minify")
    @MainActor
    func craPayloadMinify() async throws {
        self.privacyManager.enableFeatures(.all)

        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted

        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied

        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
        Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.region?.identifier
        expectedPayload.channel.timeZone =
        TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = ["foo", "bar"]
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = [
            "location": "granted",
            "display_notifications": "denied"
        ]

        await MainActor.run { [expectedPayload] in
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return expectedPayload
            }
        }

        let payload = await self.channelRegistrar.channelPayload
        #expect(expectedPayload == payload)

        notificationPermission.permissionStatus = .granted

        var expectedMinimized = ChannelRegistrationPayload()
        expectedMinimized.channel.permissions = [
            "display_notifications": "granted",
            "location": "granted",
        ]

        await MainActor.run { [expectedMinimized] in
            self.channelRegistrar.payloadCreateBlock = { @Sendable () async -> ChannelRegistrationPayload? in
                return expectedMinimized
            }
        }

        let minimized = await self.channelRegistrar.channelPayload.minimizePayload(previous: payload)

        await MainActor.run { [expectedMinimized] in
            #expect(expectedMinimized == minimized)
        }
    }

    @Test("CRA payload disabled device tags")
    func craPayloadDisabledDeviceTags() async throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.isChannelTagRegistrationEnabled = false
        self.channel.tags = ["foo", "bar"]

        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
        Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.region?.identifier
        expectedPayload.channel.timeZone =
        TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = await UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.setTags = false
        expectedPayload.channel.permissions = [:]

        let payload = await self.channelRegistrar.channelPayload
        #expect(expectedPayload == payload)
    }

    @Test("CRA payload privacy manager disabled")
    func craPayloadPrivacyManagerDisabled() async throws {
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.tags = []

        let payload = await self.channelRegistrar.channelPayload
        #expect(expectedPayload == payload)
    }

    @Test("Extending CRA payload")
    func extendingCRAPayload() async throws {
        self.privacyManager.enableFeatures(.all)

        await self.channel.addRegistrationExtender { payload in
            payload.channel.pushAddress = "WHAT"
        }

        await self.channel.addRegistrationExtender { payload in
            payload.channel.pushAddress = "OK"
        }

        let payload = await self.channelRegistrar.channelPayload
        #expect(payload.channel.pushAddress == "OK")
    }

    @Test("Application did transition to foreground")
    func applicationDidTransitionToForeground() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Existing channel created notification")
    @MainActor
    func existingChannelCreatedNotification() async throws {
        self.privacyManager.enableFeatures(.all)

        // Send the registration update
        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: true
            )
        )

        // Wait for the async Task to process the update and update audience manager
        try await waitForCondition {
            self.audienceManager.channelID == "someChannelID"
        }

        // Verify the channel ID was set correctly
        #expect(self.audienceManager.channelID == "someChannelID")
    }

    @Test("New channel created notification")
    @MainActor
    func newChannelCreatedNotification() async throws {
        self.privacyManager.enableFeatures(.all)

        // Send the registration update for a new channel
        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        // Wait for the async Task to process the update and update audience manager
        try await waitForCondition {
            self.audienceManager.channelID == "someChannelID"
        }

        // Verify the channel ID was set correctly
        #expect(self.audienceManager.channelID == "someChannelID")
    }

    @Test("Identifier updates")
    @MainActor
    func identifierUpdates() async throws {
        var updates = self.channel.identifierUpdates.makeAsyncIterator()

        self.privacyManager.enableFeatures(.all)

        // Yield to ensure async stream is set up
        await Task.yield()

        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        // Yield between sends to ensure ordering
        await Task.yield()

        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )

        var value = await updates.next()
        #expect(value == "someChannelID")
        value = await updates.next()
        #expect(value == "someOtherChannelID")
    }

    @Test("Identifier updates deduping")
    @MainActor
    func identifierUpdatesDeduping() async throws {
        self.channelRegistrar.channelID = "someChannelID"

        var updates = self.channel.identifierUpdates.makeAsyncIterator()

        self.privacyManager.enableFeatures(.all)


        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )


        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )
        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )

        var value = await updates.next()
        #expect(value == "someChannelID")
        value = await updates.next()
        #expect(value == "someOtherChannelID")
    }

    @Test("Identifier update already created")
    func identifierUpdateAlreadyCreated() async throws {
        self.privacyManager.enableFeatures(.all)

        self.channelRegistrar.channelID = "someChannelID"
        var updates = self.channel.identifierUpdates.makeAsyncIterator()


        var value = await updates.next()
        #expect(value == "someChannelID")

        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )
        value = await updates.next()
        #expect(value == "someOtherChannelID")
    }


    @Test("Created identifier passed to audience manager")
    @MainActor
    func createdIdentifierPassedToAudienceManager() async throws {
        // Send the registration update
        await self.channelRegistrar.registrationUpdates.send(
            .created(
                channelID: "foo",
                isExisting: true
            )
        )

        // Wait for the async Task to process the update and pass ID to audience manager
        try await waitForCondition {
            self.audienceManager.channelID == "foo"
        }

        // Verify the audience manager received the channel ID
        #expect(self.audienceManager.channelID == "foo")
    }

    @Test("Initial identifier passed to audience manager")
    func initialIdentifierPassedToAudienceManager() async throws {
        self.channelRegistrar.channelID = "foo"
        _ = await Self.createChannel(
            dataStore: self.dataStore,
            config: self.config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
        #expect(self.audienceManager.channelID == "foo")
    }

    @Test("Locale updated")
    func localeUpdated() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: AirshipNotifications.LocaleUpdated.name,
            object: nil
        )

        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Config update")
    func configUpdate() throws {
        self.channelRegistrar.channelID = "foo"
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Config update no channel ID")
    func configUpdateNoChannelID() throws {
        self.channelRegistrar.channelID = nil
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        #expect(self.channelRegistrar.registerCalled)
    }

    @Test("Migrate push tags to channel tags")
    func migratePushTagsToChannelTags() async throws {
        self.privacyManager.enableFeatures(.all)

        self.dataStore.setObject(["cool", "rad"], forKey: "UAPushTags")
        let channel = await Self.createChannel(
            dataStore: self.dataStore,
            config: self.config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )

        #expect(channel.tags == ["cool", "rad"])
    }

    @Test("Migrate push tags to channel tags already migrated")
    func migratePushTagsToChannelTagsAlreadyMigrated() async throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.tags = ["some-random-value"]

        let channel = await Self.createChannel(
            dataStore: self.dataStore,
            config: self.config,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
        #expect(channel.tags == ["some-random-value"])
    }

    @Test("CRA payload is active flag in foreground")
    @MainActor
    func craPayloadIsActiveFlagInForeground() async throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .active

        let payload = await self.channelRegistrar.channelPayload
        #expect(payload.channel.isActive)
    }

    @Test("CRA payload is active flag in background")
    @MainActor
    func craPayloadIsActiveFlagInBackground() async throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .background


        let payload = await self.channelRegistrar.channelPayload
        #expect(!payload.channel.isActive)
    }
}
