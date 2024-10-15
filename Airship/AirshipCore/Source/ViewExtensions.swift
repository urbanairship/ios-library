/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI


public extension View {
    @ViewBuilder
    internal func ignoreKeyboardSafeArea() -> some View {
        self.ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    func applyIf<Content: View>(
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
    internal func accessible(_ accessible: Accessible?, hideIfNotSet: Bool = false, isSelected: Bool = false) -> some View {
        if let label = accessible?.contentDescription {
            self.accessibility(label: Text(label))
        } else {
            self.accessibilityHidden(hideIfNotSet)
        }

        if let role = accessible?.role {
            self.accessibilityAddTraits(role.toAccessibilityTraits(isSelected: isSelected))
        }
    }

    /// Common modifier for buttons so event handlers can be added separately to prevent tap issues
    @ViewBuilder
    internal func commonButton<Content: BaseModel>(
        _ model: Content
    ) -> some View {
        self.enableBehaviors(model.enableBehaviors)
        .visibility(model.visibility)
    }

    @ViewBuilder
    internal func common<Content: BaseModel>(
        _ model: Content,
        formInputID: String? = nil
    ) -> some View {
        self.eventHandlers(
            model.eventHandlers,
            formInputID: formInputID
        )
        .enableBehaviors(model.enableBehaviors)
        .visibility(model.visibility)
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

extension AccessibilityRole {
    func toAccessibilityTraits(isSelected: Bool = false) -> AccessibilityTraits {
        var traits: AccessibilityTraits = []

        switch self {
        case .heading:
            _ = traits.insert(.isHeader)
        case .checkbox, .radio:
            _ = traits.insert(.isButton)
            if isSelected {
                _ = traits.insert(.isSelected)
            }
        case .button:
            _ = traits.insert(.isButton)
        case .form:
            // No direct equivalent; adjust if necessary
            break
        case .radioGroup:
            // No direct equivalent; adjust if necessary
            break
        case .presentation:
            // No direct equivalent; adjust if necessary
            break
        }

        return traits
    }
}
