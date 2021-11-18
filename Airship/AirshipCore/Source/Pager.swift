import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Pager : View {
    private static let flingSpeed: CGFloat = 300.0
    private static let offsetPercent: CGFloat = 0.50

    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var context: ThomasContext

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
            get: { self.pagerState.index },
            set: { self.pagerState.index = $0 }
        )
        
        let childConstraints = ViewConstraints(width: metrics.size.width,
                                               height: metrics.size.height)
        
        let items = self.model.items
        
        VStack {
            createStack {
                ForEach(0..<items.count, id: \.self) { i in
                    VStack {
                        ViewFactory.createView(model: items[i], constraints: childConstraints)
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
        .applyIf(self.model.disableSwipe != true) { view in
            #if !os(tvOS)
            view.highPriorityGesture(
                DragGesture()
                    .updating(self.$translation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndLocation.x - value.location.x
                        let offset = value.translation.width / metrics.size.width
                        if (abs(velocity) >= Pager.flingSpeed) {
                            let newIndex = velocity > 0 ? index.wrappedValue - 1 : index.wrappedValue + 1
                            withAnimation {
                                index.wrappedValue = min(items.count - 1, max(0, newIndex))
                            }
                        } else if (abs(offset) >= Pager.offsetPercent) {
                            let newIndex = offset > 0 ? index.wrappedValue - 1 : index.wrappedValue + 1
                            withAnimation {
                                index.wrappedValue = min(items.count - 1, max(0, newIndex))
                            }
                        }
                }
            )
            #else
            view
            #endif
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
                .onAppear {
                    pagerState.pages = self.model.items.count
                }.onReceive(pagerState.$index) { value in
                    reportPage(value)
                }
        }
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
    }
    
    private func reportPage(_ index: Int) {
        if (self.lastIndex != index) {
            self.context.delegate.onPageView(pagerIdentifier: self.model.identifier,
                                                 pageIndex: index,
                                                 pageCount: self.model.items.count)
            self.lastIndex = index
        }
    }
}
     
