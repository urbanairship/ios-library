/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugPrivacyManagerView: View {

    @StateObject
    private var viewModel = ViewModel()

    @ViewBuilder
    private func makeFeatureToggle(
        _ title: String,
        _ isOn: Binding<Bool>
    ) -> some View {
        Toggle(title.localized(), isOn: isOn).frame(height: CommonItems.rowHeight)
    }

    var body: some View {
        Form {
            makeFeatureToggle("Contacts", self.$viewModel.contactsEnabled)
            
            makeFeatureToggle(
                "Tags & Attributes",
                self.$viewModel.tagsAndAttributesEnabled
            )
            
            makeFeatureToggle("Analytics", self.$viewModel.analyticsEnabled)
            
            makeFeatureToggle("Push", self.$viewModel.pushEnabled)
            
            makeFeatureToggle(
                "In App Automation",
                self.$viewModel.iaaEnabled
            )
            
            makeFeatureToggle(
                "Message Center",
                self.$viewModel.messageCenterEnabled
            )
            
            makeFeatureToggle(
                "Feature Flags",
                self.$viewModel.featureFlagEnabled
            )
        }
        .navigationTitle("Privacy Manager".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {

        @Published
        public var iaaEnabled: Bool {
            didSet {
                update(.inAppAutomation, enable: self.iaaEnabled)
            }
        }

        @Published
        public var messageCenterEnabled: Bool {
            didSet {
                update(.messageCenter, enable: self.messageCenterEnabled)
            }
        }
        
        @Published
        public var featureFlagEnabled: Bool {
            didSet {
                update(.featureFlags, enable: self.featureFlagEnabled)
            }
        }

        @Published
        public var pushEnabled: Bool {
            didSet {
                update(.push, enable: self.pushEnabled)
            }
        }

        @Published
        public var analyticsEnabled: Bool {
            didSet {
                update(.analytics, enable: self.analyticsEnabled)
            }
        }

        @Published
        public var tagsAndAttributesEnabled: Bool {
            didSet {
                update(
                    .tagsAndAttributes,
                    enable: self.tagsAndAttributesEnabled
                )
            }
        }

        @Published
        public var contactsEnabled: Bool {
            didSet {
                update(.contacts, enable: self.contactsEnabled)
            }
        }

        init() {
            if Airship.isFlying {
                let privacyManager = Airship.privacyManager
                self.iaaEnabled = privacyManager.isEnabled(.inAppAutomation)
                self.messageCenterEnabled = privacyManager.isEnabled(
                    .messageCenter
                )
                self.pushEnabled = privacyManager.isEnabled(.push)
                self.analyticsEnabled = privacyManager.isEnabled(.analytics)
                self.contactsEnabled = privacyManager.isEnabled(.contacts)
                self.tagsAndAttributesEnabled = privacyManager.isEnabled(
                    .tagsAndAttributes)
                self.featureFlagEnabled = privacyManager.isEnabled(.featureFlags)
            } else {
                self.iaaEnabled = false
                self.messageCenterEnabled = false
                self.pushEnabled = false
                self.analyticsEnabled = false
                self.contactsEnabled = false
                self.tagsAndAttributesEnabled = false
                self.featureFlagEnabled = false
            }
        }

        private func update(_ features: AirshipFeature, enable: Bool) {
            guard Airship.isFlying else { return }

            if enable {
                Airship.privacyManager.enableFeatures(features)
            } else {
                Airship.privacyManager.disableFeatures(features)
            }
        }
    }
}

#Preview {
    AirshipDebugPrivacyManagerView()
}
