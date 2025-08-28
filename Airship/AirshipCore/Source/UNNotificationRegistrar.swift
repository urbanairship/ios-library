// Copyright Airship and Contributors


@preconcurrency import UserNotifications

/// UNNotificationCenter notification registrar
struct UNNotificationRegistrar: NotificationRegistrar {

    #if !os(tvOS)
    @MainActor
    func setCategories(_ categories: Set<UNNotificationCategory>) {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    #endif

    @MainActor
    func checkStatus() async -> (UNAuthorizationStatus, AirshipAuthorizedNotificationSettings) {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return (settings.authorizationStatus, AirshipAuthorizedNotificationSettings.from(settings: settings))
    }

    func updateRegistration(
        options: UNAuthorizationOptions,
        skipIfEphemeral: Bool
    ) async -> Void {

        let requestOptions = options
        let (status, settings) = await checkStatus()

        // Skip registration if no options are enable and we are requesting no options
        if settings == [] && requestOptions == [] {
            return
        }

#if !os(tvOS) && !os(watchOS)
        // Skip registration for ephemeral if skipRegistrationIfEphemeral
        if status == .ephemeral && skipIfEphemeral {
            return
        }
#endif

        var granted = false
        // Request
        do {
            granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            AirshipLogger.error(
                "requestAuthorizationWithOptions failed with error: \(error)"
            )
        }
        AirshipLogger.debug(
            "requestAuthorizationWithOptions \(granted)"
        )
    }
}
