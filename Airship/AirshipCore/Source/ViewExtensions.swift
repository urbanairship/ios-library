/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


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
    private func applyAccessibleRole(
        _ accessible: Accessible?,
        isSelected: Bool = false
    ) -> some View {
        Group {
            switch accessible?.accessibleRole {
            case .heading(let level):
                self.applyIf(true) { view in
                    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                        view.accessibilityAddTraits(.isHeader)
                            .accessibilityHeading(level.toAccessibilityHeadingLevel())
                    } else {
                        view.accessibilityAddTraits(.isHeader)
                    }
                }
            case .checkbox:
                self.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            case .button:
                self.accessibilityAddTraits(.isButton)
            case .form:
                self
            case .radio:
                self.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            case .radioGroup:
                self
            case .presentation:
                self
            default:
                self
            }
        }
    }

    @ViewBuilder
    internal func accessible(
        _ accessible: Accessible?,
        hideIfNotSet: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        if let label = accessible?.contentDescription {
            self.accessibility(label: Text(label))
                .applyAccessibleRole(accessible, isSelected: isSelected)
        } else {
            self.accessibilityHidden(hideIfNotSet)
                .applyAccessibleRole(accessible, isSelected: isSelected)
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

extension Int {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func toAccessibilityHeadingLevel() -> AccessibilityHeadingLevel {
        switch self {
        case 1:
            return .h1
        case 2:
            return .h2
        case 3:
            return .h1
        case 4:
            return .h4
        case 5:
            return .h5
        case 6:
            return .h6
        default:
            return .unspecified
        }
    }

}
