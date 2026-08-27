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
        self.modifier(
            ThomasConstraintsViewModifier(
                constraints: constraints,
                alignment: alignment,
                fixedSize: fixedSize
            )
        )
    }
}

/// The chain lives in a `ViewModifier` instead of inline in the `View` extension so that a caller's
/// static type stays one node wide.
///
/// Each `airshipApplyIf` below is an `_ConditionalContent` that names its input type twice, so
/// applied inline every Thomas view's type doubled per branch — and this is the one modifier
/// applied to nearly every view, often more than once on a path. A stack of shapes under a toggle
/// style multiplied those branches out far enough to abort the optimizer's opaque-type
/// substitution in `-O` archive builds. A named modifier is opaque to callers: the branching is
/// expanded once, here.
private struct ThomasConstraintsViewModifier: ViewModifier {
    let constraints: ViewConstraints
    let alignment: Alignment?
    let fixedSize: Bool

    /// The frame's floor: whichever of the view's own minimum and its absolute length is larger.
    ///
    /// An absolute length has always been set as a minimum as well as a maximum, so a points-sized
    /// view is not squeezed below what it asked for. A declared minimum is the same kind of claim
    /// from a different source, so the two meet here rather than one replacing the other.
    private var floorWidth: CGFloat? {
        [
            constraints.isHorizontalAbsoluteSize ? constraints.frameWidth : nil,
            constraints.frameMinWidth
        ].compactMap { $0 }.max()
    }

    private var floorHeight: CGFloat? {
        [
            constraints.isVerticalAbsoluteSize ? constraints.frameHeight : nil,
            constraints.frameMinHeight
        ].compactMap { $0 }.max()
    }

    func body(content: Content) -> some View {
        content.frame(
            minWidth: floorWidth,
            idealWidth: constraints.frameWidth,
            maxWidth: constraints.frameWidth,
            minHeight: floorHeight,
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
        // An axis the ratio derives has to be free of the content's own idea of how big it is, and
        // `RatioLayout` is what frees it. `.aspectRatio(.fit)` can't: it proposes a ratio-fitted box
        // and then lets the child answer, so a stretchy view accepts it but a rigid one like a label
        // reports its text size instead, leaving the ratio a no-op on exactly the content that
        // needed it. Filling first — a greedy frame under the ratio — made the box answer, but left
        // the ratio deriving against whatever proposal arrived, and an unbounded one yields a box
        // far larger than the space it is in, which the parent then clips. `RatioLayout` reads the
        // proposal itself, treats infinite and absent alike as "no length on this axis", and tells
        // the content what size to be. The proposal still comes from SwiftUI, so several ratio items
        // in a stack keep fair-sharing what they're offered, which pre-computing a size here would
        // have cost.
        //
        // It carries the alignment, which is the caller's and not ours to change: with no length on
        // either axis every dimension of the frame above is nil, so it sizes to its content and its
        // alignment never applies. This is the only thing that positions anything here, and a
        // vertical stack that asked to lay out from the top would otherwise be centered.
        .airshipApplyIfPresent(unboundedRatio) { view, ratio in
            RatioLayout(
                ratio: ratio,
                // The one place `maxWidth`/`maxHeight` are a ceiling on the view rather than the
                // space its children are measured against: for this case and only this case,
                // `childConstraints` has already tightened them to the ratio box itself, so they
                // are the answer, and a proposal that says otherwise is the thing to ignore.
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
                alignment: alignment ?? .center
            ) {
                view
            }
        }
        // Both lengths are set by this point, so the frame above is already the box. The ratio stays
        // applied over the top to hold it through a pass that proposes something else — a stack
        // fair-sharing, a nil proposal, a rotation.
        .airshipApplyIfPresent(derivedRatio) { view, ratio in
            view.aspectRatio(ratio, contentMode: .fit)
        }
    }

    /// The ratio when it is the only thing giving this view a size, and `nil` otherwise.
    ///
    /// Keyed on the lengths rather than `frameWidth`/`frameHeight`, which also read nil on an axis a
    /// scroll layout left uncapped — that item has a length, it just isn't a ceiling.
    private var unboundedRatio: Double? {
        guard constraints.width == nil, constraints.height == nil else { return nil }
        return constraints.aspectRatio
    }

    /// The ratio when the view already has both lengths, one of them derived from the other.
    private var derivedRatio: Double? {
        guard constraints.width != nil || constraints.height != nil else { return nil }
        return constraints.aspectRatio
    }
}

/// Sizes content to an aspect ratio, deciding the box itself rather than negotiating for one.
///
/// Both the proposal and the constraint ceilings are read directly, and the smaller of the two wins
/// on each axis. Neither alone is enough. SwiftUI's own `.aspectRatio` sees only the proposal, and
/// gets no say in what is in it: handed an unbounded height it derives against it anyway, which is
/// how an item with both axes auto in a 60pt row became a full-width box 200pt tall with the rest
/// clipped off. But a proposal arriving as "this wide, height up to you" is the normal way a stack
/// asks a child for its size, so treating an absent height as a licence to derive from the width
/// lands in the same place. The ceilings are what settle it: for this case `childConstraints` has
/// already tightened them to the ratio box, so they say what the proposal can't.
///
/// The ratio is width over height, and the caller guarantees it is greater than zero —
/// `ViewConstraints` only carries a ratio it has already checked.
private struct RatioLayout: Layout {
    let ratio: Double
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // `safeValue` drops infinity and NaN, so nil means "unbounded" on that axis either way.
        let width = smaller(proposal.width?.safeValue, maxWidth)
        let height = smaller(proposal.height?.safeValue, maxHeight)

        return switch (width, height) {
        case (let width?, let height?):
            // Both bounded: the largest box of this ratio that fits inside them.
            CGSize(
                width: min(width, height * ratio),
                height: min(height, width / ratio)
            )
        case (let width?, nil):
            CGSize(width: width, height: width / ratio)
        case (nil, let height?):
            CGSize(width: height * ratio, height: height)
        case (nil, nil):
            // Nothing to fit inside, so fit around the content instead.
            fittedAroundContent(subviews.first?.sizeThatFits(.unspecified) ?? .zero)
        }
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let anchor = self.anchor
        let point = CGPoint(
            x: bounds.minX + (bounds.width * anchor.x),
            y: bounds.minY + (bounds.height * anchor.y)
        )

        for subview in subviews {
            subview.place(
                at: point,
                anchor: anchor,
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }

    /// Whichever bound is tighter, or the one that exists, or nothing if neither does.
    private func smaller(_ proposed: CGFloat?, _ ceiling: CGFloat?) -> CGFloat? {
        return switch (proposed, ceiling) {
        case (let proposed?, let ceiling?): min(proposed, ceiling)
        case (let proposed?, nil): proposed
        case (nil, let ceiling?): ceiling
        case (nil, nil): nil
        }
    }

    /// The smallest box of this ratio that the content fits inside: take its ideal size and grow
    /// whichever axis the ratio leaves short.
    private func fittedAroundContent(_ content: CGSize) -> CGSize {
        let fromWidth = CGSize(width: content.width, height: content.width / ratio)
        return if fromWidth.height >= content.height {
            fromWidth
        } else {
            CGSize(width: content.height * ratio, height: content.height)
        }
    }

    /// Where the content sits when it ends up smaller than the box it was given.
    private var anchor: UnitPoint {
        let x: CGFloat = if alignment.horizontal == .leading {
            0
        } else if alignment.horizontal == .trailing {
            1
        } else {
            0.5
        }

        let y: CGFloat = if alignment.vertical == .top {
            0
        } else if alignment.vertical == .bottom {
            1
        } else {
            0.5
        }

        return UnitPoint(x: x, y: y)
    }
}

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
