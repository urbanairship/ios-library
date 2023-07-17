/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct AirshipDebugView: View {

    public init() {}

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @StateObject
    private var viewModel = AirshipDebugViewModel()

    @ViewBuilder
    public var body: some View {
        Form {
            Section(header: Text("".localized())) {
                makeNavItem(
                    "Privacy Manager",
                    destination: PrivacyManagerDebugView()
                )
            }

            Section(header: Text("Channel".localized())) {
                makeInfoItem("Channel ID", viewModel.channelID)
                makeNavItem("Tags", destination: DeviceTagsDebugView())
                makeNavItem(
                    "Tag Groups",
                    destination: TagGroupsDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.channel.editTagGroups()
                    }
                )

                makeNavItem(
                    "Attributes",
                    destination: AttributesDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.channel.editAttributes()
                    }
                )

                makeNavItem(
                    "Subscription Lists",
                    destination: SubscriptionListsDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.channel.editSubscriptionLists()
                    }
                )
            }

            Section(header: Text("Contact".localized())) {
                makeNavItem(
                    "Named User",
                    self.viewModel.namedUserID,
                    destination: NamedUserDebugView()
                )
                makeNavItem(
                    "Tag Groups",
                    destination: TagGroupsDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.contact.editTagGroups()
                    }
                )

                makeNavItem(
                    "Attributes",
                    destination: AttributesDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.contact.editAttributes()
                    }
                )

                makeNavItem(
                    "Subscription Lists",
                    destination: ScopedSubscriptionListsDebugView {
                        guard Airship.isFlying else { return nil }
                        return Airship.contact.editSubscriptionLists()
                    }
                )
                makeNavItem("Add Channel", destination: AddChannelView())
            }

            Section(header: Text("Push".localized())) {
                Toggle(
                    "Notification Enabled".localized(),
                    isOn: self.$viewModel.userPushNotificationsEnabled
                )

                Toggle(
                    "Background Push Enabled".localized(),
                    isOn: self.$viewModel.backgroundPushEnabled
                )

                let optInStatus =
                    viewModel.isPushNotificationsOptedIn
                    ? "Opted-In" : "Opted-Out"
                makeInfoItem("Opt-In Status", optInStatus.localized())
                makeInfoItem("Device Token", viewModel.deviceToken)
                makeNavItem(
                    "Received Pushes",
                    destination: ReceivedPushListDebugView()
                )
            }

            Section(header: Text("Experiments".localized())) {
                makeNavItem(
                    "Feature Flags",
                    destination: FeatureFlagListDebugView()
                )
            }


            Section(header: Text("Analytics".localized())) {
                makeNavItem(
                    "Events",
                    destination: EventListDebugView()
                )
                makeNavItem(
                    "Add Custom Event",
                    destination: AddCustomEventView()
                )
                makeNavItem(
                    "Associated Identifiers",
                    destination: AnalyticsIdentifiersView()
                )
            }

            Section(header: Text("In-App Automation".localized())) {
                makeNavItem(
                    "Automations",
                    destination: InAppAutomationListDebugView()
                )

                makeNavItem(
                    "Experiments",
                    destination: ExperimentsListsDebugView()
                )

                VStack {
                    makeInfoItem(
                        "Display Interval",
                        "\(self.viewModel.displayInterval) seconds"
                    )

                    Slider(
                        value: self.$viewModel.displayInterval,
                        in: 0.0...200.0,
                        step: 1.0
                    )
                }
            }

            Section(header: Text("Preference Center".localized())) {
                makeNavItem(
                    "Preference Centers",
                    destination: PreferenceCenterListDebugView()
                )
            }

            Section(header: Text("App Info".localized())) {
                makeInfoItem("Airship SDK Version", viewModel.airshipSDKVersion)
                makeInfoItem(
                    "App Version",
                    "\(viewModel.appVersion) (\(viewModel.appVersionCode))"
                )
                makeInfoItem("Bundle ID", viewModel.bundleID)
                makeInfoItem("Time Zone", viewModel.timeZone)
                makeInfoItem("App Locale", viewModel.locale.identifier)
                Picker(
                    selection: self.$viewModel.airshipLocaleIdentifier,
                    label: Text("Locale Override".localized())
                ) {
                    let allIDs = Locale.availableIdentifiers
                    ForEach(allIDs, id: \.self) { localeID in  // <1>
                        Text(localeID)
                    }
                }
                Button("Clear Locale Override".localized()) {
                    self.viewModel.clearLocaleOverride()
                }
            }

        }
        .overlay(AirshipToast(message: self.$toastMessage))
        .navigationTitle("Airship Debug")
    }

    func copyToClipboard(value: String?) {
        guard let value = value else {
            return
        }

        UIPasteboard.general.string = value
        self.toastMessage = AirshipToast.Message(
            id: UUID().uuidString,
            text: "Copied to pasteboard!".localized(),
            duration: 1.0
        )
    }

    @ViewBuilder
    func makeInfoItem(_ title: String, _ value: String?) -> some View {
        Button(action: {
            if let value = value {
                copyToClipboard(value: value)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(value ?? "")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    func makeNavItem<Destination: View>(
        _ title: String,
        _ value: String? = nil,
        destination: @autoclosure () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(value ?? "")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func makeTextInput(
        title: String,
        placeHolder: String? = nil,
        text: Binding<String>,
        onSubmit: @escaping () -> Void
    ) -> some View {

        HStack {
            Text(title.localized())
            Spacer()

            if #available(iOS 15.0, *) {
                TextField((placeHolder ?? title).localized(), text: text)
                    .onSubmit {
                        onSubmit()
                    }
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .frame(maxWidth: .infinity)
            } else {
                TextField((placeHolder ?? title).localized(), text: text) {
                    onSubmit()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

}

private class AirshipDebugViewModel: ObservableObject {
    let bundleID = Bundle.main.bundleIdentifier
    let appVersion =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        ?? ""
    let appVersionCode =
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
    let airshipSDKVersion: String = AirshipVersion.get()
    var timeZone: String {
        return TimeZone.autoupdatingCurrent.identifier
    }

    @Published
    var channelID: String?

    @Published
    var deviceToken: String?

    @Published
    var locale: Locale

    @Published
    var namedUserID: String?

    @Published
    var airshipLocaleIdentifier: String {
        didSet {
            if Airship.isFlying {
                Airship.shared.localeManager.currentLocale = Locale(
                    identifier: self.airshipLocaleIdentifier
                )
            }
        }
    }

    @Published
    private(set) var isPushNotificationsOptedIn: Bool

    @Published
    var displayInterval: TimeInterval {
        didSet {
            guard Airship.isFlying else { return }
            InAppAutomation.shared.inAppMessageManager.displayInterval =
                displayInterval
        }
    }

    @Published
    var userPushNotificationsEnabled: Bool {
        didSet {
            guard Airship.isFlying else { return }
            if self.userPushNotificationsEnabled
                != Airship.push.userPushNotificationsEnabled
            {
                Airship.push.userPushNotificationsEnabled =
                    userPushNotificationsEnabled
            }
        }
    }

    @Published
    @MainActor
    var backgroundPushEnabled: Bool {
        didSet {
            guard Airship.isFlying else { return }
            if self.backgroundPushEnabled
                != Airship.push.backgroundPushNotificationsEnabled
            {
                Airship.push.backgroundPushNotificationsEnabled =
                    backgroundPushEnabled
            }
        }
    }

    private var subscriptions: Set<AnyCancellable> = Set()

    @MainActor
    init() {
        self.locale = Locale.autoupdatingCurrent

        if Airship.isFlying {
            self.channelID = Airship.channel.identifier
            self.deviceToken = Airship.push.deviceToken
            self.isPushNotificationsOptedIn =
                Airship.push.isPushNotificationsOptedIn
            self.airshipLocaleIdentifier =
                Airship.shared.localeManager.currentLocale.identifier
            self.userPushNotificationsEnabled =
                Airship.push.userPushNotificationsEnabled
            self.backgroundPushEnabled =
                Airship.push.backgroundPushNotificationsEnabled
            self.displayInterval =
                InAppAutomation.shared.inAppMessageManager.displayInterval
            subscribeUpdates()
        } else {
            self.channelID = "TakeOff not called"
            self.deviceToken = "TakeOff not called"
            self.isPushNotificationsOptedIn = false
            self.userPushNotificationsEnabled = false
            self.backgroundPushEnabled = false
            self.airshipLocaleIdentifier = Locale.autoupdatingCurrent.identifier
            self.namedUserID = "TakeOff not called"
            self.displayInterval = 0.0
        }
    }

    private func subscribeUpdates() {
        NotificationCenter.default
            .publisher(for: AirshipChannel.channelCreatedEvent)
            .sink(receiveValue: { _ in
                self.channelID = Airship.channel.identifier
            })
            .store(in: &self.subscriptions)

        Airship.push.notificationStatusPublisher
            .sink(receiveValue: { status in
                Task { @MainActor in
                    self.isPushNotificationsOptedIn = status.isOptedIn
                    self.deviceToken = Airship.push.deviceToken
                }
            })
            .store(in: &self.subscriptions)

        Airship.contact.namedUserIDPublisher
            .receive(on: RunLoop.main)
            .sink { namedUserID in
                self.namedUserID = namedUserID
            }
            .store(in: &self.subscriptions)

    }

    func clearLocaleOverride() {
        if Airship.isFlying {
            self.airshipLocaleIdentifier = Locale.autoupdatingCurrent.identifier
            Airship.shared.localeManager.clearLocale()
        }
    }
}

struct StoryBoardViewController: UIViewControllerRepresentable {
    let storyBoardName: String

    func updateUIViewController(
        _ uiViewController: UIViewControllerType,
        context: Context
    ) {
    }

    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(
            name: self.storyBoardName,
            bundle: DebugResources.bundle()
        )
        return storyboard.instantiateInitialViewController()!
    }
}
