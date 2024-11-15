/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

extension View {
    @ViewBuilder
    internal func ignoreKeyboardSafeArea() -> some View {
        self.ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    internal func thomasToggleStyle(
        _ style: ThomasToggleStyleInfo,
        colorScheme: ColorScheme,
        constraints: ViewConstraints,
        disabled: Bool
    ) -> some View {
        switch style {
        case .checkboxStyle(let style):
            self.toggleStyle(
                AirshipCheckboxToggleStyle(
                    viewConstraints: constraints,
                    info: style,
                    colorScheme: colorScheme,
                    disabled: disabled
                )
            )
        case .switchStyle(let style):
            self.toggleStyle(
                AirshipSwitchToggleStyle(
                    info: style,
                    colorScheme: colorScheme,
                    disabled: disabled
                )
            )
        }
    }
    @ViewBuilder
    public func airshipApplyIf<Content: View>(
        _ predicate: @autoclosure () -> Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        if predicate() {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    internal func addTapGesture(action: @escaping () -> Void) -> some View {
        if #available(iOS 13.0, macOS 10.15, tvOS 16.0, watchOS 6.0, *) {
            self.onTapGesture(perform: action)
                .accessibilityAction(.default, action)
        } else {
            // Tap gesture is unavailable on tvOS versions prior to tvOS 16 for now
            self.accessibilityAction(.default, action)
        }
    }

    @ViewBuilder
    internal func accessible(
        _ accessible: ThomasAccessibleInfo?,
        fallbackContentDescription: String? = nil,
        hideIfDescriptionIsMissing: Bool = true
    ) -> some View {
        let label = accessible?.resolveContentDescription ?? fallbackContentDescription
        if accessible?.accessibilityHidden == true {
            self.accessibilityHidden(true)
        } else if let label {
            self.accessibility(label: Text(label))
        } else if hideIfDescriptionIsMissing {
            self.accessibilityHidden(true)
        } else {
            self
        }
    }

    @ViewBuilder
    internal func addSelectedTrait(
        _ isSelected: Bool
    ) -> some View {
        if isSelected {
            self.accessibilityAddTraits(.isSelected)
        } else {
            self
        }
    }

    @ViewBuilder
    internal func accessibilityActionsCompat<Content>(@ViewBuilder _ content: () -> Content) -> some View where Content : View {
        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            self.accessibilityActions(content)
        } else {
            self
        }
    }

    @ViewBuilder
    internal func thomasCommon(
        _ info: some ThomasViewInfo.BaseInfo,
        formInputID: String? = nil
    ) -> some View {
        self.thomasBackground(
            color: info.commonProperties.backgroundColor,
            colorOverrides: info.commonOverrides?.backgroundColor,
            border: info.commonProperties.border,
            borderOverrides: info.commonOverrides?.border
        )
        .thomasEventHandlers(
            info.commonProperties.eventHandlers,
            formInputID: formInputID
        )
        .thomasEnableBehaviors(info.commonProperties.enabled)
        .thomasVisibility(info.commonProperties.visibility)
    }

    internal func viewModifiers<Modifiers: ViewModifier>(
        @AirshipViewModifierBuilder modifiers: () -> Modifiers
    ) -> some View {
        self.modifier(modifiers())
    }
    
    internal func overlayView<T: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> T
    ) -> some View {
        overlay(
            Group(content: content),
            alignment: alignment
        )
    }
}


@resultBuilder
struct AirshipViewModifierBuilder {

    static func buildBlock() -> EmptyModifier {
        EmptyModifier()
    }

    static func buildOptional<VM0: ViewModifier>(_ vm0: VM0?)
        -> some ViewModifier
    {
        return Optional(viewModifier: vm0)
    }

    static func buildBlock<VM0: ViewModifier>(_ vm0: VM0) -> some ViewModifier {
        return vm0
    }

    static func buildBlock<VM0: ViewModifier, VM1: ViewModifier>(
        _ vm0: VM0,
        _ vm1: VM1
    ) -> some ViewModifier {
        return vm0.concat(vm1)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2) -> some ViewModifier {
        return vm0.concat(vm1).concat(vm2)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3) -> some ViewModifier {
        return vm0.concat(vm1).concat(vm2).concat(vm3)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier,
        VM5: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4, _ vm5: VM5)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4).concat(vm5)
    }

    private struct Optional<Modifier: ViewModifier>: ViewModifier {
        let viewModifier: Modifier?

        func body(content: Content) -> some View {
            if let viewModifier = viewModifier {
                content.modifier(viewModifier)
            } else {
                content
            }
        }
    }
}

