/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Container view.

struct Container: View {
    /// Container model.
    let info: ThomasViewInfo.Container

    /// View constraints.
    let constraints: ViewConstraints

    /// Quick setting to use legacy container on iOS 16+
    private static let forceLegacyContainer: Bool = false

    var body: some View {
        NewContainer(info: self.info, constraints: self.constraints)
    }
}

fileprivate struct NewContainer: View {
    @Environment(\.layoutDirection) var layoutDirection

    /// Container model.
    let info: ThomasViewInfo.Container

    /// View constraints.
    let constraints: ViewConstraints

    var body: some View {
        ContainerLayout(
            items: self.info.properties.items,
            constraints: self.constraints,
            layoutDirection: layoutDirection
        ) {
            ForEach(0..<info.properties.items.count, id: \.self) { idx in
                childItem(idx, item: info.properties.items[idx])
            }
        }
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

    }
}

fileprivate struct ContainerLayout: Layout {
    struct Cache {
        var childSizes: [CGSize]
    }

    let items: [ThomasViewInfo.Container.Item]
    let constraints: ViewConstraints
    let layoutDirection: LayoutDirection

    func makeCache(subviews: Subviews) -> Cache {
        Cache(
            childSizes: Array(repeating: .zero, count: subviews.count)
        )
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        var maxWidth: CGFloat = (constraints.width == nil) ? 0 : proposal.width ?? 0
        var maxHeight: CGFloat = (constraints.height == nil) ? 0 : proposal.height ?? 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.dimensions(in: proposal)
            cache.childSizes[index] = CGSize(width: size.width, height: size.height)

            maxWidth = max(maxWidth, size.width)
            maxHeight = max(maxHeight, size.height)
        }

        return CGSize(width: maxWidth, height: maxHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        for (index, subview) in subviews.enumerated() {
            let item = items[index]
            let childSize = cache.childSizes[index]

            let x: CGFloat = switch item.position.horizontal {
            case .start:
                layoutDirection == .leftToRight ? bounds.minX : bounds.maxX - childSize.width
            case .end:
                layoutDirection == .leftToRight ? bounds.maxX - childSize.width : bounds.minX
            case .center:
                bounds.midX - (childSize.width / 2)
            }

            let y: CGFloat = switch item.position.vertical {
            case .top:
                bounds.minY
            case .bottom:
                bounds.maxY - childSize.height
            case .center:
                bounds.midY - (childSize.height / 2)
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(
                    width: childSize.width,
                    height: childSize.height
                )
            )
        }
    }
}
