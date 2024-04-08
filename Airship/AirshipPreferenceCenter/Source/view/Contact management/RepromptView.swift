/* Copyright Airship and Contributors */

import SwiftUI

/// TODO: Probably just remove this. It's not used anywhere but the preview - we have a bunch of models that are basically all the same with slight variations, we don't need a separate view for each.
//// MARK: Reprompt view
//public struct RePromptView: View {
//
//    public var item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions
//
//    public var registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?
//
//    public var channel: AssociatedChannelType
//
//    /// The preference center theme
//    public var theme: PreferenceCenterTheme.ContactManagement?
//
//    @State
//    private var selectedSender = PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
//        senderId: "",
//        placeholderText: "",
//        countryCode: "",
//        displayName: ""
//    )
//
//    @State
//    private var inputText = ""
//
//    @State
//    private var isValid = true
//
//    @State
//    private var startEditing = false
//
//    @State
//    private var disposable: AirshipMainActorCancellableBlock? = nil
//
//    public init(
//        item: PreferenceCenterConfig.ContactManagementItem.RepromptOptions,
//        registrationOptions: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions?,
//        channel: AssociatedChannel,
//        theme: PreferenceCenterTheme.ContactManagement? = nil
//    ) {
//        self.item = item
//        self.registrationOptions = registrationOptions
//        self.channel = channel
//        self.theme = theme
//    }
//
//    public var body: some View {
//        VStack(alignment: .leading) {
//            /// Title
//            Text(self.item.message)
//                .textAppearance(
//                    theme?.subtitleAppearance,
//                    base: DefaultContactManagementSectionStyle.subtitleAppearance
//                )
//                .fixedSize(horizontal: false, vertical: true)
//
//            HStack {
//                ChannelTextField(
//                    registrationOptions: self.registrationOptions,
//                    selectedSender: self.$selectedSender,
//                    inputText: self.$inputText,
//                    isValid: self.$isValid,
//                    showErrorText: self.$startEditing,
//                    theme: self.theme)
//                .padding(EdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 3))
//
//                //Retry button
//                LabeledButton(
//                    item: self.item.button,
//                    theme: self.theme) {
//                        // TODO: Retry
//                    }
//            }
//        }
//    }
//}
