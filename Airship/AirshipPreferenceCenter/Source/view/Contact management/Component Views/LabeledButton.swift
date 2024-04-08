/* Copyright Airship and Contributors */
import SwiftUI

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
    var action: (()->())?

    private let cornerRadius: CGFloat = 8
    private let disabledOpacity: CGFloat = 0.2
    private let buttonPadding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    private let outlineWidth: CGFloat = 1

    private let  minButtonWidth: CGFloat = 44

    init(
        type: LabeledButtonType = .defaultType,
        item: PreferenceCenterConfig.ContactManagementItem.LabeledButton,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        theme: PreferenceCenterTheme.ContactManagement?,
        action: (() -> ())?
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
        /// Outline types don't usually show progress - but want this to be right in case we ever do. Default fallback should be light color on dark background.
        let fallbackColor = type == .defaultType ? Color.primary.inverted() : Color.primary

        Text(self.item.text)
            .textAppearance(
                theme?.buttonLabelAppearance,
                base: typedAppearance
            )
            .opacity(1)
            .airshipApplyIf(isLoading) {
                $0
                    .opacity(0) /// Hide the text underneath the loader
                    .overlay(
                        ProgressView()
                            .airshipSetTint(color: theme?.buttonLabelAppearance?.color ?? fallbackColor)
                    )
            }
    }

    private var typedAppearance: PreferenceCenterTheme.TextAppearance {
        /// Light on dark for outlined and destructive types
        type == .outlineType ?  DefaultContactManagementSectionStyle.buttonLabelOutlineAppearance : DefaultContactManagementSectionStyle.buttonLabelAppearance
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
        VStack {
            Button {
                if let action = action {
                    action()
                }
            } label: {
                buttonLabel
            }
        }
        .frame(minWidth: minButtonWidth)
        .padding(buttonPadding)
        .background(typedBackgroundColor)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(type == .outlineType ? Color.primary : Color.clear, lineWidth: type == .outlineType ? outlineWidth : 0)
        )
        .disabled(!isEnabled)
        .optAccessibilityLabel(
            string: self.item.contentDescription
        )
    }
}

