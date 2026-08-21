/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Linear Layout - either a VStack or HStack depending on the direction.

struct LinearLayout: View {
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment

    /// LinearLayout model.
    private let info: ThomasViewInfo.LinearLayout

    /// View constraints.
    private let constraints: ViewConstraints

    @State
    private var numberGenerator: RepeatableNumberGenerator = RepeatableNumberGenerator()

    @State
    private var measuredSize: CGSize? = nil

    /// Carries the stack-axis base across passes. A reference type on purpose: it's bookkeeping for
    /// the measurement we already react to, not state that should itself trigger a render.
    @State
    private var tracker: StackAxisTracker = StackAxisTracker()

    /// Whether this stack has no length of its own and no item that could give it one.
    ///
    /// Settled in `init` because answering it walks the whole subtree, while neither input changes
    /// for the life of the view: `body` runs as often as SwiftUI likes, the walk happens once.
    private let stackAxisLacksBasis: Bool

    /// The same question on the other axis.
    ///
    /// The cross axis looked safe because items can't grow it — a percentage there resolves against
    /// a measurement it had no part in. True while the axis is fixed. When it is auto the stack
    /// takes it from its widest item, so an item that is both the widest and a percentage of it is
    /// a fraction of a length it sets itself: `w = Pw`, which walks to zero a pass at a time and
    /// takes the stack down with it. A sibling with a length of its own breaks the loop, which is
    /// what this asks about. So does an item at exactly 100%: the whole of the widest is the
    /// widest, so the feedback settles where it starts instead of walking.
    private let crossAxisLacksBasis: Bool

    init(info: ThomasViewInfo.LinearLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        let isVertical = info.properties.direction == .vertical
        self.stackAxisLacksBasis = Self.lacksBasis(
            info: info,
            constraints: constraints,
            on: isVertical ? .vertical : .horizontal,
            lengthIsWidestItem: false
        )
        self.crossAxisLacksBasis = Self.lacksBasis(
            info: info,
            constraints: constraints,
            on: isVertical ? .horizontal : .vertical,
            lengthIsWidestItem: true
        )
    }

    private static func lacksBasis(
        info: ThomasViewInfo.LinearLayout,
        constraints: ViewConstraints,
        on axis: Axis,
        lengthIsWidestItem: Bool
    ) -> Bool {
        let isAuto = axis == .vertical ? constraints.height == nil : constraints.width == nil
        guard isAuto else { return false }

        // A ratio is a length by another route: it derives one axis from the other, so the box that
        // reaches us is settled before any item is asked for anything. Auto on both axes only means
        // nothing was declared, not that nothing supplies it — the items are a share of a length
        // that exists, and asking them about it gets the wrong answer.
        guard constraints.aspectRatio == nil else { return false }

        let items = info.properties.items
        return !items.isEmpty && items.allSatisfy { item in
            let constraint = item.size.constraint(on: axis)
            // Exactly 100% counts as a basis on an axis whose length is the widest item: 100% of
            // the widest is the widest, so the measurement fed back settles on the first pass
            // instead of walking. This is what makes a stack of all-100% buttons match the widest
            // one. Fractions below the whole still walk to zero, and on the stack axis items sum
            // rather than overlay, where 100% diverges, so it stays basis-less there.
            if lengthIsWidestItem, case .percent(let percent) = constraint, percent == 100 {
                return false
            }
            return !constraint.establishesLength(view: item.view, on: axis)
        }
    }

    @ViewBuilder
    @MainActor
    private func makeVStack(
        items: [ThomasViewInfo.LinearLayout.Item],
        parentConstraints: ViewConstraints
    ) -> some View {

        VStack(alignment: .center, spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
#if os(tvOS)
                HStack {
                    childItem(items[index], parentConstraints: parentConstraints)
                }
                .frame(maxWidth: .infinity)
                .focusSection()
                .airshipApplyIf(
                    items[index].hasPerItemAlignment(stackDirection: .vertical)
                ) {
                    $0.frame(
                        maxWidth: .infinity,
                        alignment: items[index].position?.alignment ?? .center
                    )
                }
#else
                childItem(items[index], parentConstraints: parentConstraints)
                    .airshipApplyIf(
                        items[index].hasPerItemAlignment(stackDirection: .vertical)
                    ) {
                        $0.frame(
                            maxWidth: .infinity,
                            alignment: items[index].position?.alignment ?? .center
                        )
                    }
#endif
            }
        }
        .airshipGeometryGroupCompat()
        .accessibilityElement(children: .contain)
        .constraints(self.constraints, alignment: .top)
        .applyFixedSizeForAlignment(info: self.info, constraints: constraints)
    }


    @ViewBuilder
    @MainActor
    private func makeHStack(
        items: [ThomasViewInfo.LinearLayout.Item],
        parentConstraints: ViewConstraints
    ) -> some View {

        HStack(alignment: .center, spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
#if os(tvOS)
                VStack {
                    childItem(items[index], parentConstraints: parentConstraints)
                }
                .frame(maxHeight: .infinity)
                .focusSection()
                .airshipApplyIf(
                    items[index].hasPerItemAlignment(stackDirection: .horizontal)
                ) {
                    $0.frame(
                        maxHeight: .infinity,
                        alignment: items[index].position?.alignment ?? .center
                    )
                }
#else
                childItem(items[index], parentConstraints: parentConstraints)
                    .airshipApplyIf(
                        items[index].hasPerItemAlignment(stackDirection: .horizontal)
                    ) {
                        $0.frame(
                            maxHeight: .infinity,
                            alignment: items[index].position?.alignment ?? .center
                        )
                    }
#endif
            }
        }
        .constraints(constraints, alignment: .leading)
        .applyFixedSizeForAlignment(info: self.info, constraints: constraints)
    }


    @ViewBuilder
    @MainActor
    private func makeStack() -> some View {
        if self.info.properties.direction == .vertical {
            makeVStack(
                items: orderedItems(),
                parentConstraints: parentConstraints()
            )
        } else {
            makeHStack(
                items: orderedItems(),
                parentConstraints: parentConstraints()
            )
        }
    }

    var body: some View {
        makeStack()
            .airshipMeasureView($measuredSize)
            .clipped()
            .thomasCommon(self.info)
    }

    @ViewBuilder
    @MainActor
    private func childItem(
        _ item: ThomasViewInfo.LinearLayout.Item,
        parentConstraints: ViewConstraints
    ) -> some View {
        // Our own stroke isn't deducted here any more: our length already had it taken out when our
        // parent sized us, so what we hand out is the content box. The child's stroke comes out of
        // the child's length for the same reason.
        let constraints = parentConstraints.childConstraints(
            item.size,
            margin: item.margin,
            borderStrokeWidth: item.view.borderStrokeWidth,
            safeAreaInsetsMode: .consume
        )

        thomasEnvironment.viewFactory.createView(item.view, constraints: constraints)
            // A percentage is a footprint — `childConstraints` takes the margins out of the share and
            // `.margin()` puts them back, so the two make up the item's whole extent. When there is no
            // basis the share is never taken out in the first place: the item falls back to its own
            // content, and its margins belong around that content like any other item's.
            .margin(item.margin)
#if os(tvOS)
            .focusSection()
#endif
    }


    private func parentConstraints() -> ViewConstraints {
        let isVertical = self.info.properties.direction == .vertical

        // The cross axis is settled by the measurement: items can't grow it, so what we measured
        // is what percentages should resolve against. The stack axis isn't, because a percent item
        // is a fraction of a length it also contributes to — the measurement already has the last
        // pass's answer baked into it. Solve for the fixed point instead of walking toward it.
        let stackAxisBase = resolvedStackAxisBase(
            measured: isVertical ? measuredSize?.height : measuredSize?.width,
            isAuto: isVertical ? self.constraints.height == nil : self.constraints.width == nil
        )

        // Unless nothing supplies the cross axis either, in which case the measurement is the
        // items' own extent coming back to them and "items can't grow it" stops being true. Hand
        // back nothing, the same answer the stack axis gives: the percentages fall back to their
        // content and there is nothing to re-resolve on the next pass.
        let crossAxisBase = crossAxisLacksBasis
            ? nil
            : (isVertical ? measuredSize?.width : measuredSize?.height)

        var constraints = self.constraints.fillingMeasured(
            width: isVertical ? crossAxisBase : stackAxisBase,
            height: isVertical ? stackAxisBase : crossAxisBase
        )

        if isVertical {
            constraints.isVerticalFixedSize = false
        } else {
            constraints.isHorizontalFixedSize = false
        }

        return constraints
    }

    /// The stack-axis length percent items should resolve against: `S / (1 - P)`, where `S` is the
    /// extent of everything on that axis which isn't a percent, and `P` the percentages summed.
    ///
    /// That's the only self-consistent answer. A `height: 50%` item beside a fixed 200pt one makes
    /// the stack 400 tall, not 300 — at 300 the item would be 100, which is a third of the stack
    /// rather than half. Feeding the raw measurement back converges on the same number, but
    /// geometrically: 216 → 308 → 354 → 377 → … → 400, over fifty-odd passes for a 50% item, and
    /// far worse as the percentage grows (the error shrinks by a factor of `P` each time).
    ///
    /// `S` can't be measured directly — the stack reports its whole length — but it's recoverable.
    /// Subtract what the percent items were resolved to when this tree was built, which is known
    /// from the base we handed them. `S` doesn't depend on those items, so a single subtraction
    /// lands on the fixed point.
    private func resolvedStackAxisBase(measured: CGFloat?, isAuto: Bool) -> CGFloat? {
        guard isAuto else { return measured }

        let isVertical = self.info.properties.direction == .vertical

        // Every item is a share of a length none of them supplies, so there is no base here to take a
        // share of. Answer nothing rather than measuring: percent children of a nil length resolve to
        // auto, so they size to their own content and nothing is fed back for the next pass to
        // re-resolve. Zero is the other reading — `H(1 - P) = S` with `S = 0` forces `H` to zero — but
        // it renders the items away, and an author who wrote `100%` on a label wants to see the label,
        // not an empty stack. Both answers settle; only this one is visible enough to debug.
        guard !stackAxisLacksBasis else { return nil }

        guard let measured else { return nil }

        let percentTotal = stackAxisPercentTotal

        // Nothing on this axis is a percent, so there's nothing to solve for — the stack is just
        // the sum of its items and the measurement already says so.
        guard percentTotal > 0 else { return measured }

        // The percentages meet or exceed the whole stack, so `S / (1 - P)` has no positive
        // solution: the items want more than there is, whatever the stack turns out to be.
        //
        // Hand back the bound we were given rather than our own measurement. Feeding the
        // measurement back makes each pass `percentTotal` times the last, and at 1 or more that
        // expands instead of converging. A real bound is a constant, so the layout settles: percent
        // items are `maxHeight` with no `minHeight` while point-sized items are rigid, so the stack
        // pays the fixed items first and fair-shares the rest — 200 plus two 100% items in 480pt
        // renders 200/140/140, matching Android's slot distribution.
        //
        // Only if it is a real bound, though. An auto ancestor fills its measurement in as a length,
        // and the maximum we inherit from it is then this stack's own height by another route.
        // Handing that back is the divergence above with no cap to stop it: three 100% rows measure
        // ~3x taller, which raises the bound, which grows the rows, until SwiftUI is handed an
        // infinite height and traps. Nothing is the honest answer there — percent children of a nil
        // length resolve to auto, so the rows size to their content and there is nowhere to grow.
        guard percentTotal < 1 else {
            let stackAxis: Axis.Set = isVertical ? .vertical : .horizontal
            guard !self.constraints.measuredAxes.contains(stackAxis) else { return nil }
            let bound = isVertical ? self.constraints.maxHeight : self.constraints.maxWidth
            return bound?.safeValue
        }

        // SwiftUI may evaluate `body` more than once for the same layout. Each evaluation has to
        // resolve against the base the current tree was built with, so only advance when the
        // measurement actually moved.
        if tracker.lastMeasured == measured, let base = tracker.base {
            return base
        }

        let base: CGFloat
        if let previous = tracker.base {
            let fixedExtent = measured - resolvedPercentExtent(base: previous)
            if fixedExtent >= 0 {
                // Rounded so the loop settles on a whole point instead of chasing the last 1e-14.
                base = (fixedExtent / (1 - percentTotal)).rounded()
            } else {
                // fixedExtent < 0 means the previous base was built for larger constraints
                // (e.g. after a rotation where the stack axis shrank). Re-seed from the
                // current measurement rather than clamping to 0 and collapsing the layout.
                base = measured
            }
        } else {
            // First measurement: this tree was built before we had any base, so the percent items
            // fell back to auto and their contribution is their own content — not something we can
            // subtract out. Take the measurement as-is; the next pass has a base to work from.
            base = measured
        }

        tracker.lastMeasured = measured
        tracker.base = base
        return base
    }

    /// The declared percentages on the stack axis, summed (0.5 for a lone `50%` item).
    private var stackAxisPercentTotal: CGFloat {
        self.info.properties.items.reduce(0) { total, item in
            total + (stackAxisConstraint(item).percentFraction ?? 0)
        }
    }

    /// The space the percent items occupy on the stack axis, given [base] — their resolved size
    /// on the stack axis (margins cancel: `.margin()` re-adds what `childConstraints` removed).
    /// Our stroke isn't taken out here any more. It comes out of our own length before we get it, so
    /// `base` is already the content box the percentages were resolved against — subtracting it a
    /// second time recovered an `S` that was short by the stroke, and the stack settled oversized.
    private func resolvedPercentExtent(base: CGFloat) -> CGFloat {
        return self.info.properties.items.reduce(0) { total, item in
            guard let fraction = stackAxisConstraint(item).percentFraction else { return total }
            return total + max(0, min(fraction * base, base))
        }
    }

    private func stackAxisConstraint(
        _ item: ThomasViewInfo.LinearLayout.Item
    ) -> ThomasSizeConstraint {
        self.info.properties.direction == .vertical ? item.size.height : item.size.width
    }

    private func orderedItems() -> [ThomasViewInfo.LinearLayout.Item] {
        guard self.info.properties.randomizeChildren == true else {
            return self.info.properties.items
        }
        var generator = self.numberGenerator
        generator.repeatNumbers()
        return self.info.properties.items.shuffled(using: &generator)
    }
}

/// Stack-axis base carried between passes, along with the measurement it was derived from.
fileprivate final class StackAxisTracker {
    var lastMeasured: CGFloat?
    var base: CGFloat?
}

fileprivate extension ThomasSizeConstraint {
    /// The percentage as a fraction, or nil if this isn't a percent constraint.
    var percentFraction: CGFloat? {
        if case .percent(let percent) = self {
            return percent / 100.0
        }
        return nil
    }
}

fileprivate final class RepeatableNumberGenerator: RandomNumberGenerator {
    private var numbers: [UInt64] = []
    private var index: Int = 0
    private var numberGenerator: SystemRandomNumberGenerator = SystemRandomNumberGenerator()

    func next() -> UInt64 {
        defer {
            self.index += 1
        }

        guard index < numbers.count else {
            let next = numberGenerator.next()
            numbers.append(next)
            return next
        }
        return numbers[index]
    }

    func repeatNumbers() {
        index = 0
    }
}

fileprivate extension ThomasViewInfo.LinearLayout.Item {
    func hasPerItemAlignment(stackDirection: ThomasDirection) -> Bool {
        guard let position = self.position else { return false }
        switch(stackDirection) {
        case .horizontal: return position.vertical != .center
        case .vertical: return position.horizontal != .center
        }
    }
}

fileprivate extension View {
    @ViewBuilder
    func applyFixedSizeForAlignment(
        info: ThomasViewInfo.LinearLayout,
        constraints: ViewConstraints
    ) -> some View {
        if info.properties.direction == .horizontal {
            let hasPerItemAlignment = info.properties.items.contains {
                $0.hasPerItemAlignment(stackDirection: .horizontal)
            }

            if hasPerItemAlignment, constraints.height == nil {
                self.fixedSize(horizontal: false, vertical: true)
            } else {
                self
            }
        } else {
            let hasPerItemAlignment = info.properties.items.contains {
                $0.hasPerItemAlignment(stackDirection: .vertical)
            }

            if hasPerItemAlignment, constraints.width == nil {
                self.fixedSize(horizontal: true, vertical: false)
            } else {
                self
            }
        }
    }
}
