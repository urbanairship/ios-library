/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Container view.

struct Container: View {
    /// Container model.
    private let info: ThomasViewInfo.Container

    /// View constraints.
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.Container, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        NewContainer(info: self.info, constraints: self.constraints)
    }
}

fileprivate struct NewContainer: View {
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutDirection) private var layoutDirection

    /// Container model.
    private let info: ThomasViewInfo.Container

    /// View constraints.
    private let constraints: ViewConstraints

    @State private var measuredSize: CGSize? = nil

    /// Whether this container has no length of its own on an axis and no item that could give it one.
    ///
    /// Per axis, unlike a stack: a container overlays its items rather than summing them, so width and
    /// height are settled independently and one can lack a basis while the other doesn't. Settled in
    /// `init` because both are read once per child and answering them walks the whole subtree, while
    /// neither input changes for the life of the view.
    private let verticalLacksBasis: Bool
    private let horizontalLacksBasis: Bool

    init(info: ThomasViewInfo.Container, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        // A ratio derives one axis from the other, so a box with one has a length whatever its
        // items declare, and the items are a share of something real.
        let hasRatio = constraints.aspectRatio != nil
        self.verticalLacksBasis = constraints.height == nil && !hasRatio
            && Self.lacksBasis(info: info, on: .vertical)
        self.horizontalLacksBasis = constraints.width == nil && !hasRatio
            && Self.lacksBasis(info: info, on: .horizontal)
    }

    private static func lacksBasis(info: ThomasViewInfo.Container, on axis: Axis) -> Bool {
        let items = info.properties.items
        return !items.isEmpty && items.allSatisfy { item in
            let constraint = item.size.constraint(on: axis)
            // Exactly 100% counts as a basis: a container is its largest item on either axis, and
            // 100% of the largest is the largest, so the measurement fed back settles on the first
            // pass instead of walking. Fractions below the whole still walk to zero.
            if case .percent(let percent) = constraint, percent == 100 {
                return false
            }
            return !constraint.establishesLength(view: item.view, on: axis)
        }
    }

    var body: some View {
        ContainerLayout(
            constraints: self.constraints,
            layoutDirection: layoutDirection
        ) {
            ForEach(0..<info.properties.items.count, id: \.self) { idx in
                childItem(idx, item: info.properties.items[idx])
            }
        }
        .accessibilityElement(children: .contain)
        .airshipGeometryGroupCompat()
        .constraints(constraints)
        .airshipMeasureView($measuredSize)
        .clipped()
        .thomasCommon(self.info)
    }


    @ViewBuilder
    @MainActor
    private func childItem(_ index: Int, item: ThomasViewInfo.Container.Item) -> some View {
        let consumeSafeAreaInsets = item.ignoreSafeArea != true

        // A share of our own measurement is a floor for the item, not a length.
        //
        // We are as tall as our tallest item, so an item asking for the whole of us is asking for
        // the whole of itself. Handed that as a length it is capped at what it was already measured
        // to be, and then we measure the cap coming back — an answer any height satisfies, so the
        // container held whatever it started at and nothing below could grow it. A scroll whose
        // content had reached 812 sat in a container settled at 389, which was only ever its own
        // answer going round.
        //
        // As a floor it still fills us, since that is what a share of the whole means, but it is
        // free to be taller — and what it turns out to be is what we measure, and what we are. The
        // space we were given still caps it, so it cannot outrun a ceiling further up.
        //
        // Only for a length that came from measuring ourselves. One handed down by our own parent
        // is a real length, and a share of it is exactly that share.
        let measuredShareAxes: Axis.Set = {
            var axes: Axis.Set = []
            if constraints.width == nil { axes.insert(.horizontal) }
            if constraints.height == nil { axes.insert(.vertical) }
            return axes
        }()

        let childConstraints = self.constraints
            // Nothing rather than the measurement on an axis with no basis. Feeding the measurement
            // back would let the items settle on their own content while still calling it a share of
            // the container, which is circular. Leaving the length nil says the same thing honestly:
            // percent resolves to auto, the items size to their content, and there is nothing to
            // re-resolve on the next pass.
            .fillingMeasured(
                width: horizontalLacksBasis ? nil : measuredSize?.width,
                height: verticalLacksBasis ? nil : measuredSize?.height
            )
            // Our stroke was taken out of our own length before we got it, so this is the content
            // box already; the child's stroke comes out of the child's length the same way.
            .childConstraints(
                item.size,
                margin: item.margin,
                borderStrokeWidth: item.view.borderStrokeWidth,
                safeAreaInsetsMode: consumeSafeAreaInsets ? .consumeMargin : .ignore
            )
            .flooringMeasuredShare(of: item.size, on: measuredShareAxes)

        thomasEnvironment.viewFactory.createView(
            item.view,
            constraints: childConstraints
        )
        // Margins are inside a percentage's share. With no basis the share is never taken, so the item
        // falls back to its content and its margins belong around that content as usual.
        .margin(item.margin)
        .airshipApplyIf(consumeSafeAreaInsets) {
            $0.padding(self.constraints.safeAreaInsets)
        }
        .frame(
            alignment: item.position.alignment
        )
        .layoutValue(key: ContainerLayout.ContainerItemPositionKey.self, value: item.position)
    }
}

fileprivate struct ContainerLayout: Layout {
    struct ContainerItemPositionKey: LayoutValueKey {
        static let defaultValue: ThomasPosition = ThomasPosition(horizontal: .center, vertical: .center)
    }
    
    let constraints: ViewConstraints
    let layoutDirection: LayoutDirection

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // The proposal is a ceiling to grow from, not a size to adopt, and it arrives infinite
        // often enough to matter — a scroll proposes ∞ on its axis, and `maxHeight: .infinity`
        // above us propagates one down. Taking it raw returns an infinite size, which the
        // measuring GeometryReader in the background then has to place content inside of.
        var maxWidth: CGFloat = (constraints.width == nil) ? 0 : (proposal.width?.safeValue ?? 0)
        var maxHeight: CGFloat = (constraints.height == nil) ? 0 : (proposal.height?.safeValue ?? 0)

        for subview in subviews {
            let size = subview.dimensions(in: proposal)
            maxWidth = max(maxWidth, size.width.safeValue ?? 0)
            maxHeight = max(maxHeight, size.height.safeValue ?? 0)
        }

        return CGSize(width: maxWidth, height: maxHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            let position = subview[ContainerItemPositionKey.self]

            // Re-measure with the actual bounds so placement uses the size the child
            // will actually occupy, not a stale cached size from an earlier sizeThatFits
            // pass (e.g. an ideal-size pass that proposed full-width).
            let placementProposal = ProposedViewSize(
                width: bounds.width,
                height: bounds.height
            )
            let dims = subview.dimensions(in: placementProposal)
            let childSize = CGSize(
                width: dims.width.safeValue ?? 0,
                height: dims.height.safeValue ?? 0
            )

            let x: CGFloat = switch position.horizontal {
            case .start:
                layoutDirection == .leftToRight ? bounds.minX : bounds.maxX - childSize.width
            case .end:
                layoutDirection == .leftToRight ? bounds.maxX - childSize.width : bounds.minX
            case .center:
                bounds.midX - (childSize.width / 2)
            }

            let y: CGFloat = switch position.vertical {
            case .top:
                bounds.minY
            case .bottom:
                bounds.maxY - childSize.height
            case .center:
                bounds.midY - (childSize.height / 2)
            }

            subview.place(
                at: CGPoint(
                    x: x.safeValue ?? bounds.minX,
                    y: y.safeValue ?? bounds.minY
                ),
                proposal: placementProposal
            )
        }
    }
}

fileprivate extension ViewConstraints {
    /// Moves a percentage's length to the floor, on an axis where the share came from a measurement.
    ///
    /// The length is taken as it stands rather than worked out again from the percentage. It has
    /// already had this item's margins, any safe-area insets it consumes and its own border stroke
    /// taken out of it, and a floor recomputed from the raw share carries none of that: the item
    /// stands at the whole share and wears its margins outside it, so its footprint comes to more
    /// than the measurement the share was taken from, and the next pass takes a share of that.
    ///
    /// A ratio is left alone. It has already derived one axis from the other by this point, and the
    /// two are a pair — releasing the one the share settled leaves a hard length on one axis, a free
    /// one on the other, and `.aspectRatio(.fit)` over the top of both.
    func flooringMeasuredShare(of size: ThomasSize, on axes: Axis.Set) -> ViewConstraints {
        guard size.aspectRatio == nil else { return self }

        var copy = self

        if axes.contains(.horizontal), case .percent = size.width, let share = copy.width {
            copy.width = nil
            copy.minWidth = max(copy.minWidth ?? 0, share)
        }

        if axes.contains(.vertical), case .percent = size.height, let share = copy.height {
            copy.height = nil
            copy.minHeight = max(copy.minHeight ?? 0, share)
        }

        return copy
    }
}
