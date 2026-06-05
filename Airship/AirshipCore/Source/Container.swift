/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

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
    @Environment(\.layoutDirection) private var layoutDirection

    /// Container model.
    private let info: ThomasViewInfo.Container

    /// View constraints.
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.Container, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
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
        .clipped()
        .thomasCommon(self.info)
    }

    @ViewBuilder
    @MainActor
    private func childItem(_ index: Int, item: ThomasViewInfo.Container.Item) -> some View {
        let consumeSafeAreaInsets = item.ignoreSafeArea != true

        let borderPadding = self.info.commonProperties.border?.strokeWidth ?? 0
        let childConstraints = self.constraints.childConstraints(
            item.size,
            margin: item.margin,
            padding: borderPadding,
            safeAreaInsetsMode: consumeSafeAreaInsets ? .consumeMargin : .ignore
        )

        ViewFactory.createView(
            item.view,
            constraints: childConstraints
        )
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
        static let defaultValue = ThomasPosition(horizontal: .center, vertical: .center)
    }
    
    let constraints: ViewConstraints
    let layoutDirection: LayoutDirection

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        var maxWidth: CGFloat = (constraints.width == nil) ? 0 : proposal.width ?? 0
        var maxHeight: CGFloat = (constraints.height == nil) ? 0 : proposal.height ?? 0

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
