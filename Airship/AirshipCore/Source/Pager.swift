import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Pager : View {
    private static let flingSpeed: CGFloat = 300.0
    private static let offsetPercent: CGFloat = 0.50

    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.isVisible) var isVisible
    @Environment(\.layoutState) var layoutState

    let model: PagerModel
    let constraints: ViewConstraints
    
    @State var lastIndex = -1

    @GestureState private var translation: CGFloat = 0

    init(model: PagerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    @ViewBuilder
    func createStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 14.0, tvOS 14.0, *) {
            LazyHStack(spacing: 0) {
                content()
            }
        } else {
            HStack(spacing: 0) {
                content()
            }
        }
    }
    
    @ViewBuilder
    func createPager(metrics: GeometryProxy) -> some View {
        let index = Binding<Int>(
            get: { self.pagerState.pageIndex },
            set: { self.pagerState.pageIndex = $0 }
        )
        
        let childConstraints = ViewConstraints(width: metrics.size.width,
                                               height: metrics.size.height,
                                               isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
                                               isVerticalFixedSize: self.constraints.isVerticalFixedSize,
                                               safeAreaInsets: self.constraints.safeAreaInsets)
        
        let items = self.model.items
        let allowSwipe = self.model.disableSwipe != true && items.count > 1

        VStack {
            createStack {
                ForEach(0..<items.count, id: \.self) { i in
                    VStack {
                        ViewFactory.createView(model: items[i].view, constraints: childConstraints)
                            .environment(\.isVisible, self.isVisible && i == index.wrappedValue)
                    }
                    .frame(width: metrics.size.width, height: metrics.size.height)
                }
            }
            .offset(x: -(metrics.size.width * CGFloat(index.wrappedValue)))
            .offset(x: calcDragOffset(index: index.wrappedValue))
            .animation(.interactiveSpring())
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .leading)
        .clipped()
        .applyIf(allowSwipe) { view in
            #if !os(tvOS)
            view.simultaneousGesture(
                DragGesture()
                    .updating(self.$translation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndLocation.x - value.location.x
                        let offset = value.translation.width / metrics.size.width
                        if (abs(velocity) >= Pager.flingSpeed) {
                            attemptSwipe(index, indexOffset: velocity > 0 ? -1 : 1)
                        } else if (abs(offset) >= Pager.offsetPercent) {
                            attemptSwipe(index, indexOffset: offset > 0 ? -1 : 1)
                        }
                }
            )
            #else
            view
            #endif
        }
    }
    
    private func attemptSwipe(_ index: Binding<Int>, indexOffset: Int) {
        let nextIndex = index.wrappedValue + indexOffset
        guard nextIndex < self.model.items.count else { return }
        guard nextIndex >= 0 else { return }
        guard nextIndex != index.wrappedValue else { return }
            
        thomasEnvironment.pageSwiped(self.pagerState,
                                     fromIndex: index.wrappedValue,
                                     toIndex: nextIndex,
                                     layoutState: layoutState)
        
        withAnimation {
            index.wrappedValue = nextIndex
        }
    }
    
    private func calcDragOffset(index: Int) -> CGFloat {
        var dragOffSet = self.translation
        
        if (index <= 0) {
            dragOffSet = min(dragOffSet, 0)
        } else if (index >= self.model.items.count - 1) {
            dragOffSet = max(dragOffSet, 0)
        }
        
        return dragOffSet
    }

    @ViewBuilder
    var body: some View {
        GeometryReader { metrics in
            createPager(metrics: metrics)
                .onReceive(pagerState.$pageIndex) { value in
                    pagerState.pages = self.model.items.map { $0.identifier }
                    reportPage(value)
                }
        }
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }
    
    private func reportPage(_ index: Int) {
        if (self.lastIndex != index) {
            if (index == self.model.items.count - 1) {
                self.pagerState.completed = true
            }
            self.thomasEnvironment.pageViewed(self.pagerState, layoutState: layoutState)
            self.lastIndex = index

            // Run any actions set on the current page
            let page = self.model.items[index]
            self.thomasEnvironment.runActions(page.displayActions,layoutState: layoutState)
        }
    }
}
     
