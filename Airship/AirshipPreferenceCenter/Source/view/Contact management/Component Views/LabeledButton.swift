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
    var action: () -> Void
    
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
        return color ?? PreferenceCenterDefaults.buttonBackgroundColor
    }
    
    private var destructiveBackgroundColor: Color {
        let color = colorScheme.airshipResolveColor(light: theme?.buttonDestructiveBackgroundColor, dark: theme?.buttonDestructiveBackgroundColorDark)
        
        return color ?? PreferenceCenterDefaults.buttonDestructiveBackgroundColor
    }
    
    @ViewBuilder
    private var buttonLabel: some View {
        let labelColor = colorScheme.airshipResolveColor(
            light: theme?.buttonLabelAppearance?.color,
            dark: theme?.buttonLabelAppearance?.colorDark
        ) ?? AirshipSystemColors.label
        
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
                        ProgressView().tint(labelColor)
                    )
            }
    }
    
    private var typedAppearance: PreferenceCenterTheme.TextAppearance {
        switch type {
        case .defaultType:
            return PreferenceCenterDefaults.buttonLabelAppearance
        case .destructiveType:
            return PreferenceCenterDefaults.buttonLabelDestructiveAppearance
        case .outlineType:
            return PreferenceCenterDefaults.buttonLabelOutlineAppearance
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
#if !os(tvOS)
        let defaultStrokeColor = type == .outlineType ? AirshipSystemColors.label : Color.clear
        let strokeColor = colorScheme.airshipResolveColor(light: theme?.backgroundColor, dark: theme?.backgroundColorDark) ?? defaultStrokeColor
        
        let borderShape = RoundedRectangle(cornerRadius: cornerRadius)
        let strokeWidth = type == .outlineType ? outlineWidth : 0
#endif

        Button {
            action()
        } label: {
            buttonLabel
                .padding(buttonPadding)
                .frame(minWidth: minButtonWidth)
#if !os(tvOS)
                .background(
                    borderShape
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        .background(borderShape.inset(by: strokeWidth).fill(typedBackgroundColor))
                )
                .padding(strokeWidth)
#endif
        }
        .disabled(!isEnabled)
        .optAccessibilityLabel(
            string: self.item.contentDescription
        )
#if os(tvOS)
        .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
#elseif os(visionOS)
        .buttonBorderShape(.roundedRectangle(radius: cornerRadius))
        .buttonStyle(.plain)
#endif
    }
}
