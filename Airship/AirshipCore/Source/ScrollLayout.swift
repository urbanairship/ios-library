/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Scroll view layout
@available(iOS 14.0.0, tvOS 14.0, *)
struct ScrollLayout : View {

    /// ScrollLayout model.
    let model: ScrollLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @State private var scrollTask: (String, Task<Void, Never>)?

    private static let scrollInterval: TimeInterval = 0.01

    init(model: ScrollLayoutModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    @ViewBuilder
    private func makeScrollView() -> some View {
        let isVertical = self.model.direction == .vertical
        let axis = isVertical ? Axis.Set.vertical : Axis.Set.horizontal

        ScrollViewReader { proxy in
            ScrollView(axis) {
                makeContent()
            }
            .clipped()
            .onChange(
                of: self.thomasEnvironment.keyboardState
            ) { newValue in
                if let focusedID = self.thomasEnvironment.focusedID {
                    switch (newValue) {
                    case .hidden:
                        scrollTask?.1.cancel()
                    case .displaying(let duration):
                        let task = Task {
                            await self.startScrolling(
                                scrollID: focusedID,
                                proxy: proxy,
                                duration: duration
                            )
                        }
                        self.scrollTask = (focusedID, task)
                    case .visible:
                        scrollTask?.1.cancel()
                        proxy.scrollTo(focusedID)
                    }
                } else {
                    scrollTask?.1.cancel()
                }
            }
        }
    }

    @ViewBuilder
    func makeContent() -> some View {
        ZStack {
            ViewFactory.createView(
                model: self.model.view,
                constraints: self.childConstraints()
            )
            .fixedSize(
                horizontal: self.model.direction == .horizontal,
                vertical: self.model.direction == .vertical
            )
        }.frame(alignment: .topLeading)
    }

    @ViewBuilder
    var body: some View {
        makeScrollView()
            .constraints(self.constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
    }

    private func childConstraints() -> ViewConstraints {
        var childConstraints = constraints
        if (self.model.direction == .vertical) {
            childConstraints.height = nil
            childConstraints.isVerticalFixedSize = false
        } else {
            childConstraints.width = nil
            childConstraints.isHorizontalFixedSize = false
        }

        return childConstraints
    }

    @MainActor
    private func startScrolling(
        scrollID: String,
        proxy: ScrollViewProxy,
        duration: TimeInterval
    ) async {
        var remaining = duration
        repeat {
            proxy.scrollTo(scrollID)
            remaining = remaining - ScrollLayout.scrollInterval
            try? await Task.sleep(
                nanoseconds: UInt64(ScrollLayout.scrollInterval * 1_000_000_000)
            )
        } while(remaining > 0 && !Task.isCancelled)
    }
}
