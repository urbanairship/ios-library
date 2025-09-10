/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

extension View {
    @ViewBuilder
    internal func thomasToggleStyle(
        _ style: ThomasToggleStyleInfo,
        constraints: ViewConstraints
    ) -> some View {
        switch style {
        case .checkboxStyle(let style):
            self.toggleStyle(
                AirshipCheckboxToggleStyle(
                    viewConstraints: constraints,
                    info: style
                )
            )
        case .switchStyle(let style):
            self.toggleStyle(
                AirshipSwitchToggleStyle(
                    info: style
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
    public func airshipGeometryGroupCompat() -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.geometryGroup()
        } else {
            self.transformEffect(.identity)
        }
    }

    @ViewBuilder
    internal func addTapGesture(action: @escaping () -> Void) -> some View {
        self.onTapGesture(perform: action)
            .accessibilityAction(.default, action)
    }

    @ViewBuilder
    internal func accessible(
        _ accessible: ThomasAccessibleInfo?,
        associatedLabel: String?,
        fallbackContentDescription: String? = nil,
        hideIfDescriptionIsMissing: Bool
    ) -> some View {
        let contentDescription = accessible?.resolveContentDescription ?? fallbackContentDescription
        if accessible?.accessibilityHidden == true {
            self.accessibilityHidden(true)
        } else if let contentDescription, let associatedLabel {
            self.accessibilityLabel(associatedLabel)
                .accessibilityHint(contentDescription)
        } else if let contentDescription {
            self.accessibilityLabel(contentDescription)
        } else if let associatedLabel {
            self.accessibilityLabel(associatedLabel)
        }else if hideIfDescriptionIsMissing {
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
    internal func thomasCommon(
        _ info: any ThomasViewInfo.BaseInfo,
        formInputID: String? = nil
    ) -> some View {
        self.thomasBackground(
            color: info.commonProperties.backgroundColor,
            colorOverrides: info.commonOverrides?.backgroundColor,
            border: info.commonProperties.border,
            borderOverrides: info.commonOverrides?.border
        )
        .thomasStateTriggers(info.commonProperties.stateTriggers)
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

    @MainActor
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
