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
    @Environment(\.colorScheme)
    private var colorScheme

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
        let color = colorScheme.airshipResolveColor(light: theme?.buttonBackgroundColor, dark: theme?.buttonBackgroundColorDark)
        return color ?? DefaultContactManagementSectionStyle.buttonBackgroundColor
    }

    private var destructiveBackgroundColor: Color {
        let color = colorScheme.airshipResolveColor(light: theme?.buttonDestructiveBackgroundColor, dark: theme?.buttonDestructiveBackgroundColorDark)

        return color ?? DefaultContactManagementSectionStyle.buttonDestructiveBackgroundColor
    }

    @ViewBuilder
    private var buttonLabel: some View {
        let tintColor = colorScheme.airshipResolveColor(light: theme?.buttonLabelAppearance?.color, dark: theme?.buttonLabelAppearance?.colorDark)

        Text(self.item.text)
            .textAppearance(
                theme?.buttonLabelAppearance,
                base: typedAppearance,
                colorScheme: colorScheme
            )
            .opacity((isEnabled ? 1 : disabledOpacity))
            .airshipApplyIf(isLoading) {
                $0
                    .opacity(0) /// Hide the text underneath the loader
                    .overlay(
                        ProgressView()
                            .airshipSetTint(color: tintColor ?? DefaultColors.primaryInvertedText)
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

    @ViewBuilder
    var body: some View {
        let buttonBackgroundColor = colorScheme.airshipResolveColor(light: theme?.backgroundColor, dark: theme?.backgroundColorDark)

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
                .stroke(type == .outlineType ? buttonBackgroundColor ?? DefaultColors.primaryText : buttonBackgroundColor ?? Color.clear, lineWidth: type == .outlineType ? outlineWidth : 0)
        )
        .accessibilityLabel(item.contentDescription ?? "")
        .disabled(!isEnabled)
        .optAccessibilityLabel(
            string: self.item.contentDescription
        )
    }
}

