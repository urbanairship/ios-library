/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

extension View {

    @ViewBuilder
    func foreground(_ color: ThomasColor?, colorScheme: ColorScheme, fallbackColor: Color? = nil) -> some View {
        if let color = color?.toColor(colorScheme) ?? fallbackColor {
            self.foregroundColor(color)
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
    /// A length is also the ideal and the maximum here, which is what nearly every view wants. On
    /// an axis named in `uncappedAxes` the length doesn't reach the frame at all and serves only as
    /// the reference percent children resolve against — a scroll layout's content takes its
    /// percentages of the viewport but sizes to its content.
    ///
    /// The ideal has to go as well as the maximum: a scroll applies `fixedSize` on its axis, which
    /// makes SwiftUI take the ideal, so leaving it set pins the content to the viewport however
    /// open the maximum is.
    ///
    /// `constraints.maxWidth`/`maxHeight` are deliberately not used: they carry the space
    /// available to a view, which is what its children are measured against, not a ceiling on the
    /// view itself.
    func constraints(
        _ constraints: ViewConstraints,
        alignment: Alignment? = nil,
        fixedSize: Bool = false
    ) -> some View {
        self.frame(
            minWidth: constraints.isHorizontalAbsoluteSize ? constraints.frameWidth : nil,
            idealWidth: constraints.frameWidth,
            maxWidth: constraints.frameWidth,
            minHeight: constraints.isVerticalAbsoluteSize ? constraints.frameHeight : nil,
            idealHeight: constraints.frameHeight,
            maxHeight: constraints.frameHeight,
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
        .airshipApplyIfPresent(constraints.aspectRatio) { view, ratio in
            view.aspectRatio(ratio, contentMode: .fit)
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
        AccessibleModifier(
            content: self,
            accessible: accessible,
            associatedLabel: associatedLabel,
            fallbackContentDescription: fallbackContentDescription,
            hideIfDescriptionIsMissing: hideIfDescriptionIsMissing
        )
    }
}

@MainActor
private struct AccessibleModifier<Content: View>: View {
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment

    fileprivate let content: Content
    fileprivate let accessible: ThomasAccessibleInfo?
    fileprivate let associatedLabel: String?
    fileprivate let fallbackContentDescription: String?
    fileprivate let hideIfDescriptionIsMissing: Bool

    @ViewBuilder
    var body: some View {
        let contentDescription = accessible.map {
            thomasEnvironment.resolveContentDescription(for: $0)
        } ?? fallbackContentDescription

        if accessible?.accessibilityHidden == true {
            content.accessibilityHidden(true)
        } else if let contentDescription, let associatedLabel {
            content.accessibilityLabel(associatedLabel)
                .accessibilityHint(contentDescription)
        } else if let contentDescription {
            content.accessibilityLabel(contentDescription)
        } else if let associatedLabel {
            content.accessibilityLabel(associatedLabel)
        } else if hideIfDescriptionIsMissing {
            content.accessibilityHidden(true)
        } else {
            content
        }
    }
}

internal struct ThomasCommonScope: OptionSet {
    let rawValue: UInt

    public static let background: ThomasCommonScope = ThomasCommonScope(rawValue: 1 << 0)
    public static let stateTriggers: ThomasCommonScope = ThomasCommonScope(rawValue: 1 << 1)
    public static let eventHandlers: ThomasCommonScope = ThomasCommonScope(rawValue: 1 << 2)
    public static let enableBehaviors: ThomasCommonScope = ThomasCommonScope(rawValue: 1 << 3)
    public static let visibility: ThomasCommonScope = ThomasCommonScope(rawValue: 1 << 4)

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
        fileprivate let viewModifier: Modifier?

        func body(content: Content) -> some View {
            if let viewModifier = viewModifier {
                content.modifier(viewModifier)
            } else {
                content
            }
        }
    }
}
