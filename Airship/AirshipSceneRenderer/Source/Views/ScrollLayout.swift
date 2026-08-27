/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Scroll view layout

struct ScrollLayout: View {
    
    /// ScrollLayout model.
    private let info: ThomasViewInfo.ScrollLayout
    
    /// View constraints.
    private let constraints: ViewConstraints
    
    @State private var contentSize: CGSize? = nil
    @State private var measuredFrameSize: CGSize? = nil
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @State private var scrollTask: (String, Task<Void, Never>)?
    
    private static let scrollInterval: TimeInterval = 0.01
    
    
    init(info: ThomasViewInfo.ScrollLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }
    
    @ViewBuilder
    private func makeScrollView(axis: Axis.Set) -> some View {
        ScrollView(axis) {
            makeContent()
                .background(
                    GeometryReader(content: { contentMetrics -> Color in
                        let size = contentMetrics.size
                        DispatchQueue.main.async {
                            if (self.contentSize != size) {
                                self.contentSize = size
                            }
                        }
                        return Color.clear
                    })
                )
        }
#if os(iOS)
        .scrollDismissesKeyboard(
            self.thomasEnvironment.focusedID != nil ? .immediately : .never
        )
#endif
    }
    
    @ViewBuilder
    private func makeScrollView() -> some View {
        let isVertical = self.info.properties.direction == .vertical
        let axis = isVertical ? Axis.Set.vertical : Axis.Set.horizontal
        
        ScrollViewReader { proxy in
            makeScrollView(axis: axis)
                .clipped()
                .airshipOnChangeOf(self.thomasEnvironment.keyboardState) { [weak thomasEnvironment = thomasEnvironment] newValue in
                    if let focusedID = thomasEnvironment?.focusedID {
                        switch newValue {
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
        .airshipApplyIf(self.shouldApplyFrameSize) { view in
            if let limit = self.measuredContentDimension {
                // Content has been measured: ask for that height, and take no more. The ideal is
                // what does the asking — a maximum alone permits an ancestor to offer the content
                // height without ever prompting it to, so an auto-height ancestor kept offering
                // whatever it already had and the scroll sat there. It hugged on the first pass,
                // where `fixedSize` below takes the ideal, and then let go the moment it had
                // measured itself: a modal grew to its content, dropped back, and stayed put while
                // the content inside went on growing.
                //
                // Still squeezable, since the ideal is a request and the maximum is the only cap:
                // an ancestor with less to give offers less, and the scroll scrolls.
                switch (info.properties.direction) {
                case .vertical:
                    view.frame(idealHeight: limit, maxHeight: limit)
                case .horizontal:
                    view.frame(idealWidth: limit, maxWidth: limit)
                }
            } else {
                // Not yet measured: hug the content's natural size on this first pass. Previously the
                // scroll collapsed to 0 here (`?? 0`), which made an auto-height parent (e.g. a modal
                // with min_height) measure a near-zero content height and latch to its min_height,
                // forcing the content to scroll even though it fit. Hugging via fixedSize lets the
                // parent measure the true content height, so it can size correctly before the scroll
                // becomes squeezable on the next pass.
                view.fixedSize(
                    horizontal: info.properties.direction == .horizontal,
                    vertical: info.properties.direction == .vertical
                )
            }
        }
    }

    /// The already-measured content size along the scroll axis, or `nil` before the first measurement.
    private var measuredContentDimension: CGFloat? {
        switch (info.properties.direction) {
        case .vertical:
            return self.contentSize?.height
        case .horizontal:
            return self.contentSize?.width
        }
    }

    private var shouldApplyFrameSize: Bool {
        switch (info.properties.direction) {
        case .vertical:
            self.constraints.height == nil
        case .horizontal:
            self.constraints.width == nil
        }
    }
    
    
    @ViewBuilder
    func makeContent() -> some View {
        ZStack {
            thomasEnvironment.viewFactory.createView(
                self.info.properties.view,
                constraints: self.childConstraints()
            )
            .fixedSize(
                horizontal: self.info.properties.direction == .horizontal,
                vertical: self.info.properties.direction == .vertical
            )
        }
        .frame(alignment: .topLeading)
    }
    
    @ViewBuilder
    var body: some View {
        makeScrollView()
            .constraints(self.constraints)
            .airshipMeasureView($measuredFrameSize)
            .thomasCommon(self.info)
#if os(tvOS)
            .focusSection()
#endif
    }
    
    private func childConstraints() -> ViewConstraints {
        let isVertical = info.properties.direction == .vertical

        // The viewport is what percentages resolve against, on both axes, so fill it in as the
        // length. Naming the scroll axis as uncapped is what lets the content measure past it —
        // otherwise the length doubles as the frame's maximum and `100% + 50% + 25%` compresses
        // into a single screen instead of scrolling a screen and three quarters.
        var childConstraints = constraints.fillingMeasured(
            width: measuredFrameSize?.width,
            height: measuredFrameSize?.height
        )
        childConstraints.uncappedAxes = isVertical ? .vertical : .horizontal

        if isVertical {
            childConstraints.maxHeight = nil
            childConstraints.isVerticalFixedSize = false
        } else {
            childConstraints.maxWidth = nil
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
            proxy.scrollTo(scrollID, anchor: .center)
            remaining = remaining - ScrollLayout.scrollInterval
            try? await Task.sleep(
                nanoseconds: UInt64(ScrollLayout.scrollInterval * 1_000_000_000)
            )
        } while remaining > 0 && !Task.isCancelled
    }
}
