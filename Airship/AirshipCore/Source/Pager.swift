import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Pager : View {
    private static let minDragWidth: CGFloat = 10
    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var context: ThomasContext

    let model: PagerModel
    let constraints: ViewConstraints
    
    @State var lastIndex = -1

    init(model: PagerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
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
        if #available(iOS 14.0.0, tvOS 14.0, *), self.model.disableSwipe != true {
            TabView(selection: index) {
                ForEach(0..<items.count, id: \.self) { i in
                    ViewFactory.createView(model: items[i],
                                           constraints: childConstraints)
                        .tag(i)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        } else {
            VStack {
                HStack(spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { i in
                        VStack {
                            ViewFactory.createView(model: items[i], constraints: childConstraints)
                        }
                        .frame(width: metrics.size.width, height: metrics.size.height)
                    }
                }
                .offset(x: -(metrics.size.width * CGFloat(index.wrappedValue)))
            }
            .frame(width: metrics.size.width, height: metrics.size.height, alignment: .leading)
            .clipped()
            .applyIf(self.model.disableSwipe != false) { view in
                #if !os(tvOS)
                view.highPriorityGesture(DragGesture().onEnded { drag in
                    let dragWidth = drag.translation.width
                    
                    if (dragWidth > Pager.minDragWidth) {
                        withAnimation {
                            index.wrappedValue = max(index.wrappedValue - 1, 0)
                        }
                    } else if (dragWidth < Pager.minDragWidth) {
                        withAnimation {
                            index.wrappedValue = min(index.wrappedValue + 1, items.count - 1)
                        }
                    }
                })
                #else
                view
                #endif
            }
        }
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
        }.constraints(constraints)
       
    }
    
    private func reportPage(_ index: Int) {
        if (self.lastIndex != index) {
            self.context.eventHandler.onPageView(pagerIdentifier: self.model.identifier,
                                                 pageIndex: index,
                                                 pageCount: self.model.items.count)
            self.lastIndex = index
        }
    }
}
     
