/* Copyright Airship and Contributors */


import SwiftUI

/// Scroll view layout

struct ScrollLayout: View {
    
    /// ScrollLayout model.
    let info: ThomasViewInfo.ScrollLayout
    
    /// View constraints.
    let constraints: ViewConstraints
    
    @State private var contentSize: CGSize? = nil
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @State private var scrollTask: (String, Task<Void, Never>)?
    
    private static let scrollInterval: TimeInterval = 0.01
    
    
    init(info: ThomasViewInfo.ScrollLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }
    
    @ViewBuilder
    private func makeScrollView(axis: Axis.Set) -> some View {
        
        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
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
        } else {
            ScrollView(axis) {
                makeContent()
            }
        }
    }
    
    @ViewBuilder
    private func makeScrollView() -> some View {
        let isVertical = self.info.properties.direction == .vertical
        let axis = isVertical ? Axis.Set.vertical : Axis.Set.horizontal
        
        ScrollViewReader { proxy in
            makeScrollView(axis: axis)
                .clipped()
                .airshipOnChangeOf(self.thomasEnvironment.keyboardState) { [weak thomasEnvironment] newValue in
                    if #available(iOS 16.0, tvOS 16.0, macOS 12.0, *) {
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
        }
        .airshipApplyIf(self.shouldApplyFrameSize) {
            switch (info.properties.direction) {
            case .vertical:
                $0.frame(maxHeight: self.contentSize?.height ?? 0)
            case .horizontal:
                $0.frame(maxWidth: self.contentSize?.width ?? 0)
            }
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
            ViewFactory.createView(
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
            .thomasCommon(self.info)
#if os(tvOS)
            .focusSection()
#endif
    }
    
    private func childConstraints() -> ViewConstraints {
        var childConstraints = constraints
        if self.info.properties.direction == .vertical {
            childConstraints.height = nil
            childConstraints.maxHeight = nil
            childConstraints.isVerticalFixedSize = false
        } else {
            childConstraints.width = nil
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
