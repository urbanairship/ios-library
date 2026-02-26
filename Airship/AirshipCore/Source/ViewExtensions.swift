/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

extension View {

    @ViewBuilder
    func foreground(_ color: ThomasColor?, colorScheme: ColorScheme) -> some View {
        if let color = color {
            self.foregroundColor(color.toColor(colorScheme))
        } else {
            self
        }
    }

    @ViewBuilder
    internal func applyMargin(edge: Edge.Set, margin: CGFloat?) -> some View {
        if let margin = margin {
            self.padding(edge, margin)
        } else {
            self
        }
    }

    @ViewBuilder
    func margin(_ margin: ThomasMargin?) -> some View {
        if let margin = margin {
            self.applyMargin(edge: .leading, margin: margin.start)
                .applyMargin(edge: .top, margin: margin.top)
                .applyMargin(edge: .trailing, margin: margin.end)
                .applyMargin(edge: .bottom, margin: margin.bottom)
        } else {
            self
        }
    }

    @ViewBuilder
    func constraints(
        _ constraints: ViewConstraints,
        alignment: Alignment? = nil,
        fixedSize: Bool = false
    ) -> some View {
        self.frame(
            idealWidth: constraints.width,
            maxWidth: constraints.width,
            idealHeight: constraints.height,
            maxHeight: constraints.height,
            alignment: alignment ?? .center
        )
        .airshipApplyIf(fixedSize) { view in
            view.fixedSize(
                horizontal: constraints.isHorizontalFixedSize
                    && constraints.width != nil,
                vertical: constraints.isVerticalFixedSize
                    && constraints.height != nil
            )
        }
    }
    
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
}

internal struct ThomasCommonScope: OptionSet {
    let rawValue: UInt

    public static let background = ThomasCommonScope(rawValue: 1 << 0)
    public static let stateTriggers = ThomasCommonScope(rawValue: 1 << 1)
    public static let eventHandlers = ThomasCommonScope(rawValue: 1 << 2)
    public static let enableBehaviors = ThomasCommonScope(rawValue: 1 << 3)
    public static let visibility = ThomasCommonScope(rawValue: 1 << 4)

    static let all: ThomasCommonScope = [.background, .stateTriggers, .eventHandlers, .enableBehaviors, .visibility]
}

fileprivate extension ThomasViewInfo.BaseInfo {
    var hasBackground: Bool {
        return commonProperties.border != nil ||
               commonProperties.backgroundColor != nil ||
               (commonOverrides?.border?.isEmpty == false) ||
               (commonOverrides?.backgroundColor?.isEmpty == false)
    }
}

extension View {

    @ViewBuilder
    internal func thomasCommon(
        _ info: any ThomasViewInfo.BaseInfo,
        formInputID: String? = nil,
        scope: ThomasCommonScope = .all
    ) -> some View {

        let commonOverrides = info.commonOverrides
        let commonProperties = info.commonProperties

        self.viewModifiers {
            if scope.contains(.background), info.hasBackground {
                BackgroundViewModifier(
                    backgroundColor: commonProperties.backgroundColor,
                    backgroundColorOverrides: commonOverrides?.backgroundColor,
                    border: commonProperties.border,
                    borderOverrides: commonOverrides?.border,
                    shadow: nil
                )
            }

            if scope.contains(.stateTriggers), let triggers = commonProperties.stateTriggers, !triggers.isEmpty {
                StateTriggerModifier(
                    triggers: triggers
                )
            }

            if scope.contains(.eventHandlers), let handlers = commonProperties.eventHandlers, !handlers.isEmpty {
                EventHandlerViewModifier(
                    eventHandlers: handlers,
                    formInputID: formInputID
                )
            }

            if scope.contains(.enableBehaviors), let behaviors = commonProperties.enabled, !behaviors.isEmpty {
                if behaviors.contains(.formValidation) {
                    ValidFormButtonEnableBehavior(onApply: nil)
                }

                if behaviors.contains(.pagerNext) {
                    PagerNextButtonEnableBehavior(onApply: nil)
                }

                if behaviors.contains(.pagerPrevious) {
                    PagerPreviousButtonEnableBehavior(onApply: nil)
                }

                if behaviors.contains(.formSubmission) {
                    FormSubmissionEnableBehavior(onApply: nil)
                }
            }

            if scope.contains(.visibility), let visibilityInfo = commonProperties.visibility {
                VisibilityViewModifier(visibilityInfo: visibilityInfo)
            }
        }
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

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier,
        VM5: ViewModifier,
        VM6: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4, _ vm5: VM5, _ vm6: VM6)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4).concat(vm5).concat(vm6)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier,
        VM5: ViewModifier,
        VM6: ViewModifier,
        VM7: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4, _ vm5: VM5, _ vm6: VM6, _ vm7: VM7)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4).concat(vm5).concat(vm6).concat(vm7)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier,
        VM5: ViewModifier,
        VM6: ViewModifier,
        VM7: ViewModifier,
        VM8: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4, _ vm5: VM5, _ vm6: VM6, _ vm7: VM7, _ vm8: VM8)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4).concat(vm5).concat(vm6).concat(vm7).concat(vm8)
    }

    static func buildBlock<
        VM0: ViewModifier,
        VM1: ViewModifier,
        VM2: ViewModifier,
        VM3: ViewModifier,
        VM4: ViewModifier,
        VM5: ViewModifier,
        VM6: ViewModifier,
        VM7: ViewModifier,
        VM8: ViewModifier,
        VM9: ViewModifier
    >(_ vm0: VM0, _ vm1: VM1, _ vm2: VM2, _ vm3: VM3, _ vm4: VM4, _ vm5: VM5, _ vm6: VM6, _ vm7: VM7, _ vm8: VM8, _ vm9: VM9)
        -> some ViewModifier
    {
        return vm0.concat(vm1).concat(vm2).concat(vm3).concat(vm4).concat(vm5).concat(vm6).concat(vm7).concat(vm8).concat(vm9)
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
