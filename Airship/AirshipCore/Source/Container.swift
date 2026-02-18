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
    
    struct Cache {
        var childSizes: [CGSize]
    }

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

            let childSize = CGSize(
                width: size.width.safeValue ?? 0,
                height: size.height.safeValue ?? 0
            )
            cache.childSizes[index] = childSize

            maxWidth = max(maxWidth, childSize.width)
            maxHeight = max(maxHeight, childSize.height)
        }

        return CGSize(width: maxWidth, height: maxHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        for (subviewIndex, subview) in subviews.enumerated() {
            let position = subview[ContainerItemPositionKey.self]
            let childSize = cache.childSizes[subviewIndex]

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
                proposal: ProposedViewSize(
                    width: childSize.width,
                    height: childSize.height
                )
            )
        }
    }
}
