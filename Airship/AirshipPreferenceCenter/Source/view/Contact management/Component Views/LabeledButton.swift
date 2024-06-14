/* Copyright Airship and Contributors */
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

enum LabeledButtonType {
    case defaultType
    case destructiveType
    case outlineType
}

struct LabeledButton: View {
    var item: PreferenceCenterConfig.ContactManagementItem.LabeledButton
    var type: LabeledButtonType = .defaultType

    var isEnabled: Bool
    var isLoading: Bool

    var theme: PreferenceCenterTheme.ContactManagement?
    var action: ()->()

    private let cornerRadius: CGFloat = 8
    private let disabledOpacity: CGFloat = 0.5
    private let buttonPadding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    private let outlineWidth: CGFloat = 1

    private let  minButtonWidth: CGFloat = 44

    init(
        type: LabeledButtonType = .defaultType,
        item: PreferenceCenterConfig.ContactManagementItem.LabeledButton,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        theme: PreferenceCenterTheme.ContactManagement?,
        action: @escaping () -> ()
    ) {
        self.item = item
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.theme = theme
        self.action = action
        self.type = type
    }

    private var backgroundColor: Color {
        return theme?.buttonBackgroundColor ?? DefaultContactManagementSectionStyle.buttonBackgroundColor
    }

    private var destructiveBackgroundColor: Color {
        return theme?.buttonDestructiveBackgroundColor ?? DefaultContactManagementSectionStyle.buttonDestructiveBackgroundColor
    }

    @ViewBuilder
    private var buttonLabel: some View {
        Text(self.item.text)
            .textAppearance(
                theme?.buttonLabelAppearance,
                base: typedAppearance
            )
            .opacity((isEnabled ? 1 : disabledOpacity))
            .airshipApplyIf(isLoading) {
                $0
                    .opacity(0) /// Hide the text underneath the loader
                    .overlay(
                        ProgressView()
                            .airshipSetTint(color: typedAppearance.color ?? DefaultColors.primaryInvertedText)
                    )
            }
    }

    private var typedAppearance: PreferenceCenterTheme.TextAppearance {
        switch type {
        case .defaultType:
            return DefaultContactManagementSectionStyle.buttonLabelAppearance
        case .destructiveType:
            return DefaultContactManagementSectionStyle.buttonLabelDestructiveAppearance
        case .outlineType:
            return DefaultContactManagementSectionStyle.buttonLabelOutlineAppearance
        }
    }

    private var typedBackgroundColor: Color {
        switch type {
        case .defaultType:
            return (!isEnabled ? backgroundColor.opacity(disabledOpacity) : backgroundColor)
        case .destructiveType:
            return (!isEnabled ? destructiveBackgroundColor.opacity(disabledOpacity) : destructiveBackgroundColor)
        case .outlineType:
            return Color.clear
        }
    }

    var body: some View {
        Button {
            action()
        } label: {
            buttonLabel
        }
        .frame(minWidth: minButtonWidth)
        .padding(buttonPadding)
        .background(typedBackgroundColor)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(type == .outlineType ? DefaultColors.primaryText : Color.clear, lineWidth: type == .outlineType ? outlineWidth : 0)
        )
        .accessibilityLabel(item.contentDescription ?? "")
        .disabled(!isEnabled)
        .optAccessibilityLabel(
            string: self.item.contentDescription
        )
    }
}

