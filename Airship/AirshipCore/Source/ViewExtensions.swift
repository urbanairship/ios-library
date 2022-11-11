/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func ignoreKeyboardSafeArea() -> some View {
        self.ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    func applyIf<Content: View>(
        _ predicate: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if predicate() {
            transform(self)
        } else {
            self
        }
    }

    func addTapGesture(action: @escaping () -> Void) -> some View {
        #if os(tvOS)
            // broken on tvOS for now
            self
        #else
            self.simultaneousGesture(TapGesture().onEnded(action))
        #endif
    }

    @ViewBuilder
    func accessible(_ accessible: Accessible?) -> some View {
        if let label = accessible?.contentDescription {
            self.accessibility(label: Text(label))
        } else {
            self
        }
    }

    @ViewBuilder
    func common<Content: BaseModel>(
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

    func viewModifiers<Modifiers: ViewModifier>(
        @AirshipViewModifierBuilder modifiers: () -> Modifiers
    ) -> some View {
        self.modifier(modifiers())
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
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
