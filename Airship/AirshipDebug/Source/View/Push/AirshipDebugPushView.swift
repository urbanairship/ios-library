// Copyright Airship and Contributors

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugPushView: View {

    @State
    private var toast: AirshipToast.Message? = nil

    @StateObject
    private var viewModel = ViewModel()

    @ViewBuilder
    var body: some View {
        Form {
            Section {
                Toggle(
                    "User Notifications".localized(),
                    isOn: $viewModel.isPushNotificationsOptedIn
                )
                .frame(height: 34)

                Toggle(
                    "Background Push Enabled".localized(),
                    isOn: $viewModel.backgroundPushNotificationsEnabled
                )
                .frame(height: 34)

                CommonItems.navigationLink(
                    title: "Received Pushes",
                    route: .pushSub(.recievedPushes)
                )
            }

            Section("Notification Opt-In Status") {
                if let status = self.viewModel.notificationStatus {
                    CommonItems.infoRow(
                        title: "Channel Opted-In".localized(),
                        value: status.isOptedIn.description
                    )

                    CommonItems.infoRow(
                        title: "Airship Enabled".localized(),
                        value: status.isUserNotificationsEnabled.description
                    )

                    CommonItems.infoRow(
                        title: "Push PrivacyManager Enabled".localized(),
                        value: status.isPushPrivacyFeatureEnabled.description
                    )

                    CommonItems.infoRow(
                        title: "Permission Status".localized(),
                        value: status.displayNotificationStatus.rawValue
                    )

                    CommonItems.infoRow(
                        title: "Push Token".localized(),
                        value: self.viewModel.deviceToken ?? "Not Available",
                        onTap: {
                            if let token = self.viewModel.deviceToken {
                                copyToClipboard(token)
                            }
                        }
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .toastable($toast)
        .navigationTitle("Push".localized())
    }
    
    private func copyToClipboard(_ value: String?) {
        guard let value else { return }
        value.pastleboard()
        
        self.toast = .init(text: "Copied to clipboard".localized())
    }

    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        @Published
        private(set) var deviceToken: String? = nil

        @Published
        private(set) var notificationStatus: AirshipNotificationStatus? = nil

        @Published
        public var isPushNotificationsOptedIn: Bool = false {
            didSet {
                guard
                    Airship.isFlying,
                    Airship.push.isPushNotificationsOptedIn != self.isPushNotificationsOptedIn
                else {
                    return
                }

                self.enableNotificationsTask?.cancel()

                if self.isPushNotificationsOptedIn {
                    Airship.privacyManager.enableFeatures(.push)
                    self.enableNotificationsTask = Task { [weak self] in
                        await Airship.push.enableUserPushNotifications(fallback: .systemSettings)
                        guard !Task.isCancelled else { return }
                        self?.isPushNotificationsOptedIn = Airship.push.isPushNotificationsOptedIn
                    }
                } else {
                    Airship.push.userPushNotificationsEnabled = false
                }
            }
        }

        @Published
        public var backgroundPushNotificationsEnabled: Bool = false {
            didSet {
                guard
                    Airship.isFlying,
                    Airship.push.backgroundPushNotificationsEnabled != self.backgroundPushNotificationsEnabled
                else {
                    return
                }

                Airship.push.backgroundPushNotificationsEnabled = self.backgroundPushNotificationsEnabled
            }
        }

        private var task: Task<Void, Never>? = nil
        private var enableNotificationsTask: Task<Void, Never>? = nil

        deinit {
            self.task?.cancel()
            self.enableNotificationsTask?.cancel()
        }

        @MainActor
        init() {
            if Airship.isFlying {
                self.deviceToken = Airship.push.deviceToken
                self.isPushNotificationsOptedIn = Airship.push.isPushNotificationsOptedIn
                self.backgroundPushNotificationsEnabled = Airship.push.backgroundPushNotificationsEnabled
            }

            self.task = Task { @MainActor [weak self] in
                await Airship.waitForReady()
                self?.deviceToken = Airship.push.deviceToken
                self?.isPushNotificationsOptedIn = Airship.push.isPushNotificationsOptedIn
                self?.backgroundPushNotificationsEnabled = Airship.push.backgroundPushNotificationsEnabled

                self?.notificationStatus = await Airship.push.notificationStatus

                for await update in await Airship.push.notificationStatusUpdates {
                    self?.notificationStatus = update
                    self?.deviceToken = Airship.push.deviceToken
                    self?.isPushNotificationsOptedIn = Airship.push.isPushNotificationsOptedIn
                }
            }
        }
    }
}

#Preview {
    AirshipDebugPushView()
}

