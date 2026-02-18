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
        if #available(iOS 16.0, *), !Self.forceLegacyContainer {
            NewContainer(info: self.info, constraints: self.constraints)
        } else {
            LegacyContainer(info: self.info, constraints: self.constraints)
        }
    }
}

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
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

fileprivate struct LegacyContainer: View {

    /// Container model.
    let info: ThomasViewInfo.Container

    /// View constraints.
    let constraints: ViewConstraints

    @State private var contentSize: (ViewConstraints, CGSize)? = nil

    var body: some View {
        ZStack {
            ForEach(0..<self.info.properties.items.count, id: \.self) { index in
                childItem(index, item: self.info.properties.items[index])
                    .zIndex(Double(index))
            }
        }
        .constraints(constraints)
        .clipped()
        .background(
            GeometryReader(content: { contentMetrics -> Color in
                let size = contentMetrics.size
                DispatchQueue.main.async {
                    self.contentSize = (self.constraints, size)
                }
                return Color.clear
            })
        )
        .thomasCommon(self.info)
#if os(tvOS)
            .focusSection()
#endif
    }

    @ViewBuilder
    @MainActor
    private func childItem(_ index: Int, item: ThomasViewInfo.Container.Item) -> some View {
        let placementWidth = placementWidth(item.position.horizontal)
        let placementHeight = placementHeight(item.position.vertical)
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
            idealWidth: placementWidth,
            maxWidth: placementWidth,
            idealHeight: placementHeight,
            maxHeight: placementHeight,
            alignment: item.position.alignment
        )
    }

    private func placementWidth(_ position: ThomasPosition.Horizontal) -> CGFloat? {
        guard constraints.width == nil else { return constraints.width }
        guard position != .center else { return nil }

        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.width > 0 ? contentSize.1.width : nil
        }

        return nil
    }

    private func placementHeight(_ position: ThomasPosition.Vertical) -> CGFloat? {
        guard constraints.height == nil else { return constraints.height }
        guard position != .center else { return nil }

        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.height > 0 ? contentSize.1.height : nil
        }

        return nil
    }
}

