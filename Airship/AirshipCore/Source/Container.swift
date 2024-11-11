/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Container view.

struct Container: View {

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
