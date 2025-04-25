/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct AirshipDebugView: View {
    
    public init() {}
    
    @StateObject
    private var viewModel = AirshipDebugViewModel()
    
    @ViewBuilder
    public var body: some View {
        Form {
            ForEach(viewModel.sections, id: \.self) { item in
                NavigationLink(
                    destination: makeDesitnation(item.navigation)) {
                        HStack {
                            Image(systemName: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            
                            Text(item.title.localized())
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
            }
        }
        .navigationTitle("Airship Debug")
    }
    
    @ViewBuilder
    private func makeDesitnation(_ destination: AirshipDebugViewModel.NavigationDestination) -> some View {
        switch(destination) {
        case .deviceInfo: DeviceInfoDebugView(
            appInfo: $viewModel.appInfo,
            channelId: $viewModel.channelID,
            isUserPushEnabled: $viewModel.userPushNotificationsEnabled,
            isBackgroundPushEnabled: $viewModel.backgroundPushEnabled,
            deviceToken: $viewModel.deviceToken)
        case .privacyManager: PrivacyManagerDebugView()
        case .channel: ChannelInfoDebugView(channelId: { viewModel.channelID })
        case .analytics: AnalyticsDebugView()
        case .inAppAutomation: InAppAutomationDebugView(displayInterval: self.$viewModel.displayInterval)
        case .featureFalgs: FeatureFlagDebugView()
        case .pushNotifications: ReceivedPushListDebugView()
        case .preferenceCenters: PreferenceCenterListDebugView()
        case .contacts: ContactsDebugView(
            namedUserId: $viewModel.namedUserID)
        case .appInfo: AppInfoDebugView(
            info: $viewModel.appInfo,
            selectedLocale: $viewModel.airshipLocaleIdentifier,
            onClearLocale: { viewModel.clearLocaleOverride() }
        )}
    }
}

@MainActor
private class AirshipDebugViewModel: ObservableObject {
    
    @Published
    var appInfo: AppInfo
    
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
                Airship.localeManager.currentLocale = Locale(
                    identifier: self.airshipLocaleIdentifier
                )
                
                appInfo = appInfo.copyWith(locale: self.airshipLocaleIdentifier)
            }
        }
    }
    
    @Published
    private(set) var isPushNotificationsOptedIn: Bool
    
    @Published
    @MainActor
    var displayInterval: TimeInterval {
        didSet {
            guard Airship.isFlying else { return }
            Airship.inAppAutomation.inAppMessaging.displayInterval =
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
            Airship.localeManager.currentLocale.identifier
            self.userPushNotificationsEnabled =
            Airship.push.userPushNotificationsEnabled
            self.backgroundPushEnabled =
            Airship.push.backgroundPushNotificationsEnabled
            self.displayInterval =
            Airship.inAppAutomation.inAppMessaging.displayInterval
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
        
        self.appInfo = .init(
            bundleId: Bundle.main.bundleIdentifier ?? "",
            timeZone: TimeZone.autoupdatingCurrent.identifier,
            sdkVersion: AirshipVersion.version,
            appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "",
            appCodeVersion: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "",
            applicationLocale: Locale.autoupdatingCurrent.identifier
        )
        
        if Airship.isFlying {
            subscribeUpdates()
        }
    }
    
    private func subscribeUpdates() {
        NotificationCenter.default
            .publisher(for: AirshipNotifications.ChannelCreated.name)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { _ in
                self.channelID = Airship.channel.identifier
            })
            .store(in: &self.subscriptions)
        
        Airship.push.notificationStatusPublisher
            .receive(on: RunLoop.main)
            .sink { status in
                self.isPushNotificationsOptedIn = status.isOptedIn
                self.deviceToken = Airship.push.deviceToken
            }
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
            Airship.localeManager.clearLocale()
        }
    }
    
    let sections = [
        DebugSection(
            icon: "iphone.homebutton",
            title: "Device Info",
            navigation: .deviceInfo),
        DebugSection(
            icon: "hand.raised.square.fill",
            title: "Privacy Manager",
            navigation: .privacyManager),
        DebugSection(
            icon: "arrow.left.arrow.right.square.fill",
            title: "Channel",
            navigation: .channel),
        DebugSection(
            icon: "calendar.badge.checkmark",
            title: "Analytics",
            navigation: .analytics),
        DebugSection(
            icon: "bolt.square.fill",
            title: "In-App Automation",
            navigation: .inAppAutomation),
        DebugSection(
            icon: "flag.square.fill",
            title: "Feature Flags",
            navigation: .featureFalgs),
        DebugSection(
            icon: "checkmark.bubble.fill",
            title: "Received Pushes",
            navigation: .pushNotifications),
        DebugSection(
            icon: "list.bullet.rectangle.fill",
            title: "Preference Centers",
            navigation: .preferenceCenters),
        DebugSection(
            icon: "person.crop.square.fill",
            title: "Contacts",
            navigation: .contacts),
        DebugSection(
            icon: "info.square.fill",
            title: "App Info",
            navigation: .appInfo)
    ]
    
    enum NavigationDestination {
        case deviceInfo
        case privacyManager
        case channel
        case analytics
        case inAppAutomation
        case featureFalgs
        case pushNotifications
        case preferenceCenters
        case contacts
        case appInfo
    }
    
    struct DebugSection: Sendable, Hashable {
        let icon: String
        let title: String
        let navigation: NavigationDestination
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

#Preview {
    AirshipDebugView().preferredColorScheme(.light)
}
