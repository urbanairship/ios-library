/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Linear Layout - either a VStack or HStack depending on the direction.

struct LinearLayout: View {

    /// LinearLayout model.
    let info: ThomasViewInfo.LinearLayout

    /// View constraints.
    let constraints: ViewConstraints

    @State
    private var numberGenerator = RepeatableNumberGenerator()

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
#else
                childItem(items[index], parentConstraints: parentConstraints)
#endif
            }
        }
        .constraints(self.constraints, alignment: .top)
    }

    @ViewBuilder
    @MainActor
    private func makeHStack(
        items: [ThomasViewInfo.LinearLayout.Item],
        parentConstraints: ViewConstraints
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
#if os(tvOS)
                VStack {
                    childItem(items[index], parentConstraints: parentConstraints)
                }
                .frame(maxHeight: .infinity)
                .focusSection()
#else
                childItem(items[index], parentConstraints: parentConstraints)
#endif
            }
        }
        .constraints(constraints, alignment: .leading)
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
            .clipped()
            .thomasCommon(self.info)
    }

    @ViewBuilder
    @MainActor
    private func childItem(
        _ item: ThomasViewInfo.LinearLayout.Item,
        parentConstraints: ViewConstraints
    ) -> some View {
        let constraints = parentConstraints.childConstraints(
            item.size,
            margin: item.margin,
            padding: self.info.commonProperties.border?.strokeWidth ?? 0,
            safeAreaInsetsMode: .consume
        )

        ViewFactory.createView(item.view, constraints: constraints)
            .margin(item.margin)
#if os(tvOS)
            .focusSection()
#endif
    }

    private func parentConstraints() -> ViewConstraints {
        var constraints = self.constraints

        if self.info.properties.direction == .vertical {
            constraints.isVerticalFixedSize = false
        } else {
            constraints.isHorizontalFixedSize = false
        }

        return constraints
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

class RepeatableNumberGenerator: RandomNumberGenerator {
    private var numbers: [UInt64] = []
    private var index = 0
    private var numberGenerator = SystemRandomNumberGenerator()

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
