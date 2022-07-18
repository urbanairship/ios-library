/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Linear Layout - either a VStack or HStack depending on the direction.
@available(iOS 13.0.0, tvOS 13.0, *)
struct LinearLayout : View {
    
    /// LinearLayout model.
    let model: LinearLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints

    @State
    private var numberGenerator = RepeatableNumberGenerator()

    @ViewBuilder
    func createStack() -> some View {
        let items = orderedItems()
        let parentConstraints = parentConstraints()
        if (self.model.direction == .vertical) {
            VStack(alignment: .center, spacing: 0) {
                ForEach(0..<items.count, id: \.self) { index in
                    childItem(items[index], parentConstraints: parentConstraints)
                }
            }
            .padding(self.model.border?.strokeWidth ?? 0)
            .constraints(constraints, alignment: .top)
        } else {
            HStack(spacing: 0) {
                ForEach(0..<items.count, id: \.self) { index in
                    childItem(items[index], parentConstraints: parentConstraints)
                }
            }
            .padding(self.model.border?.strokeWidth ?? 0)
            .constraints(constraints)
        }
    }
                        
    var body: some View {
        createStack()
            .clipped()
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
    }
    
    @ViewBuilder
    private func childItem(_ item: LinearLayoutItem, parentConstraints: ViewConstraints) -> some View {
        let constraints = parentConstraints.childConstraints(item.size,
                                                             margin: item.margin,
                                                             padding: self.model.border?.strokeWidth ?? 0,
                                                             safeAreaInsetsMode: .consume)

        ViewFactory.createView(model: item.view, constraints: constraints)
            .margin(item.margin)
    }

    private func parentConstraints() -> ViewConstraints {
        var constraints = self.constraints

        if (self.model.direction == .vertical) {
            constraints.isVerticalFixedSize = false
        } else {
            constraints.isHorizontalFixedSize = false
        }

        return constraints
    }

    private func orderedItems() -> [LinearLayoutItem] {
        if (self.model.randomizeChildren == true) {
            var generator = self.numberGenerator
            generator.repeatNumbers()
            return model.items.shuffled(using: &generator)
        } else {
            return self.model.items
        }
    }
}


class RepeatableNumberGenerator : RandomNumberGenerator {
    private var numbers: [UInt64] = []
    private var index = 0
    private var numberGenerator = SystemRandomNumberGenerator()

    func next() -> UInt64 {
        defer {
            self.index += 1
        }

        if (index < numbers.count) {
            return numbers[index]
        } else {
            let next = numberGenerator.next()
            numbers.append(next)
            return next
        }
    }

    func repeatNumbers() {
        index = 0
    }
}
