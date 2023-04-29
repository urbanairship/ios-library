/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine


private enum PagerStatus {
    case onStart
    case onEnd
}

private enum PagerTransition {
    case tap
    case swipe
    case automated
}

enum PagerGestureLocation {
    case top
    case bottom
    case right
    case left
    case center
    case none
}

enum PagerGestureDirection {
    case up
    case down
    case right
    case left
    case none
}

let navigationAction: [ButtonClickBehavior] = [
    .dismiss,
    .cancel,
    .pagerNext,
    .pagerPrevious,
    .pagerNextOrFirst,
    .pagerNextOrDismiss
]

struct Pager: View {
    private static let flingSpeed: CGFloat = 300.0
    private static let offsetPercent: CGFloat = 0.50
    private static let timerTransition = 0.01

    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.isVisible) var isVisible
    @Environment(\.layoutState) var layoutState
    @Environment(\.layoutDirection) var direction

    let model: PagerModel
    let constraints: ViewConstraints

    @State var lastIndex = -1

    @GestureState private var translation: CGFloat = 0

    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    @State private var pagerGestureEplorer: PagerGestureMapExplorer?
    
    init(
        model: PagerModel,
        constraints: ViewConstraints
    ) {
        self.model = model
        self.constraints = constraints
        self.timer = Timer.publish(
            every: Pager.timerTransition,
            on: .main,
            in: .default)
        .autoconnect()
    }

    @ViewBuilder
    func createStack<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyHStack(spacing: 0) {
            content()
        }
    }

    @ViewBuilder
    func createPager(metrics: GeometryProxy) -> some View {
        let index = Binding<Int>(
            get: { self.pagerState.pageIndex },
            set: { self.pagerState.pageIndex = $0 }
        )

        let childConstraints = ViewConstraints(
            width: metrics.size.width,
            height: metrics.size.height,
            isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
            isVerticalFixedSize: self.constraints.isVerticalFixedSize,
            safeAreaInsets: self.constraints.safeAreaInsets
        )

        let items = self.model.items

        VStack {
            createStack {
                ForEach(0..<items.count, id: \.self) { i in
                    VStack {
                        ViewFactory.createView(
                            model: items[i].view,
                            constraints: childConstraints
                        )
                        .environment(
                            \.isVisible,
                            self.isVisible && i == index.wrappedValue
                        )
                        .accessibilityHidden(!(self.isVisible && i == index.wrappedValue))
                    }
                    .frame(
                        width: metrics.size.width,
                        height: metrics.size.height
                    )
                }
            }
            .offset(x: -(metrics.size.width * CGFloat(index.wrappedValue)))
            .offset(x: calcDragOffset(index: index.wrappedValue))
            .animation(.interactiveSpring())
        }
        .frame(
            width: metrics.size.width,
            height: metrics.size.height,
            alignment: .leading
        )
        .clipped()
    }

    private func calcDragOffset(index: Int) -> CGFloat {
        var dragOffSet = self.translation

        if index <= 0 {
            dragOffSet = min(dragOffSet, 0)
        } else if index >= self.model.items.count - 1 {
            dragOffSet = max(dragOffSet, 0)
        }

        return dragOffSet
    }

    @ViewBuilder
    var body: some View {
        let index = Binding<Int>(
            get: { self.pagerState.pageIndex },
            set: { self.pagerState.pageIndex = $0 }
        )
        
        GeometryReader { metrics in
            createPager(metrics: metrics)
                .onAppear() {
                    pagerGestureEplorer = PagerGestureMapExplorer(
                        CGRect(
                            x: 0,
                            y: 0,
                            width: metrics.size.width,
                            height: metrics.size.height
                        )
                    )
                }
                .onReceive(pagerState.$pageIndex) { value in
                    pagerState.pages = self.model.items.map {
                        PageState(
                            identifier: $0.identifier,
                            delay: earliestNavigationAction($0.automatedActions)?.delay ?? 0.0
                        )
                    }
                    reportPage(value)
                }
                .onReceive(self.timer) { timer in
                    if let automatedActions = self.model.items[self.pagerState.pageIndex].automatedActions {
                        handlePagerProgress(automatedActions, index: index)
                    }
                }
#if !os(tvOS)
                .gesture(
                    pagerTapGesture(size: metrics.size, index: index))
                .simultaneousGesture(
                    pagerSwipeGesture(size: metrics.size, index: index))
                .simultaneousGesture(
                    pagerLongPressGesture(index: index))
                .accessibilityScrollAction { edge in
                    if (edge == Edge.leading) {
                        isRightToLeft() ? goToPreviousPage(index) : goToNextPage(index)
                    }
                    
                    if (edge == Edge.trailing) {
                        isRightToLeft() ? goToNextPage(index) : goToPreviousPage(index)
                    }
                }
#endif
        }
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }
   
    // MARK: Handle Gesture
    
    private func retrieveGestures<T: PagerGesture>(
        type: T.Type
    ) -> [T] {
        
        guard let gestures = self.model.gestures else {
            return []
        }
        
        return gestures.compactMap { gesture in
            switch gesture {
            case .tapGesture(let model):
                return model as? T
            case .swipeGesture(let model):
                return model as? T
            case .holdGesture(let model):
                return model as? T
            }
        }
    }
    
#if !os(tvOS)
    private func pagerTapGesture(
        size: CGSize,
        index: Binding<Int>
    ) -> some Gesture {
        return DragGesture(minimumDistance: 0).onEnded { value in
            if value.startLocation == value.location {
                if let pagerExplorer = pagerGestureEplorer {
                    let location = pagerExplorer.location(forPoint: value.location)
                    
                    switch location {
                    case .top:
                        handleTap(locations: [.top], index: index)
                        
                    case .bottom:
                        handleTap(locations: [.bottom], index: index)
                        
                    case .left:
                        let gestureLocations: [GestureLocation] = isRightToLeft() ? [.end, .left] : [.start, .left]
                        handleTap(locations: gestureLocations, index: index)
                        
                    case .right:
                        let gestureLocations: [GestureLocation] = isRightToLeft() ? [.start, .right] : [.end, .right]
                        handleTap(locations: gestureLocations, index: index)
                        
                    case .center:
                        handleTap(locations: [.any], index: index)
                        
                    case .none: break
                    }
                }
            }
        }
    }
    
    private func pagerSwipeGesture(
        size: CGSize,
        index: Binding<Int>
    ) -> some Gesture {
        DragGesture()
            .updating(self.$translation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let xVelocity =
                value.predictedEndLocation.x - value.location.x
                let yVelocity =
                value.predictedEndLocation.y - value.location.y
                let widhtOffset =
                value.translation.width / size.width
                let heightOffset = value.translation.height / size.height
                
                var direction: PagerGestureDirection = .none
                if abs(xVelocity) >= Pager.flingSpeed {
                    direction = xVelocity > 0 ? .left : .right
                } else if abs(widhtOffset) >= Pager.offsetPercent {
                    direction = widhtOffset > 0 ? .left : .right
                } else if abs(yVelocity) >= Pager.flingSpeed {
                    direction = yVelocity > 0 ? .down : .up
                } else if abs(heightOffset) >= Pager.offsetPercent {
                    direction = heightOffset > 0 ? .down : .up
                }
                
                if retrieveGestures(type: PagerDragGesture.self).isEmpty {
                    /// Default swipe
                    if (self.model.disableSwipe != true) {
                        if isRightToLeft() {
                            direction == .left ? goToNextPage(index, transition: .swipe) : goToPreviousPage(index, transition: .swipe)
                        } else {
                            direction == .left ? goToPreviousPage(index, transition: .swipe) : goToNextPage(index, transition: .swipe)
                        }
                    }
                } else {
                    
                    switch direction {
                    case .left:
                        let gestureDirections: [GestureDirection] = isRightToLeft() ? [.end, .left] : [.start, .left]
                        handleSwipe(directions: gestureDirections, index: index)
                        
                    case .right:
                        let gestureDirections: [GestureDirection] = isRightToLeft() ? [.start, .right] : [.end, .right]
                        handleSwipe(directions: gestureDirections, index: index)
                        
                    case .down:
                        handleSwipe(directions: [.down], index: index)
                        
                    case .up:
                        handleSwipe(directions: [.up], index: index)
                        
                    case .none: break
                    }
                }
            }
    }
    
    private func pagerLongPressGesture(
        index: Binding<Int>
    ) -> some Gesture {
        return LongPressGesture(minimumDuration: 0.001)
            .sequenced(before: DragGesture(minimumDistance: -0.1)
                .onChanged { _ in
                    handleLongPress(pagerState: .onStart, index: index)
                }
                .onEnded { value in
                    handleLongPress(pagerState: .onEnd, index: index)
                })
    }
    
#endif
    
    /// Handle tap gesture
    /// Retrieve the first available gesture with a sorted location array to handle RTL
    private func handleTap(
        locations: [GestureLocation],
        index: Binding<Int>
    ) {
        
        for location in locations {
            let gestures = retrieveGestures(type: PagerTapGesture.self)
                .filter { $0.location == location }
            if !gestures.isEmpty {
                gestures.forEach { gesture in
                    handleGestureBehavior(
                        gesture.behavior,
                        identifier: gesture.identifier,
                        transition: .tap,
                        index: index
                    )
                }
                break
            }
        }
    
    }
    
    private func handleSwipe(
        directions: [GestureDirection],
        index: Binding<Int>
    ) {
        for direction in directions {
            let gestures = retrieveGestures(type: PagerDragGesture.self)
                .filter { $0.direction == direction }
            if !gestures.isEmpty {
                gestures.forEach { gesture in
                    handleGestureBehavior(
                        gesture.behavior,
                        identifier: gesture.identifier,
                        transition: .swipe,
                        index: index
                    )
                }
                break
            }
        }
    }
    
    private func handleLongPress(
        pagerState: PagerStatus,
        index: Binding<Int>
    ) {
        
        let gestures = retrieveGestures(type: PagerHoldGesture.self)

        gestures.forEach { gesture in
            switch pagerState {
            case .onStart:
                handleGestureBehavior(
                    gesture.pressBehavior,
                    identifier: gesture.identifier,
                    index: index
                )
            case .onEnd:
                handleGestureBehavior(
                    gesture.releaseBehavior,
                    identifier: gesture.identifier,
                    index: index)
            }
        }
    }
    
    private func handleGestureBehavior(
        _ gestureBehavior: PagerGestureBehavior,
        identifier: String,
        transition: PagerTransition? = nil,
        index: Binding<Int>
    ) {
        handleActions(gestureBehavior.actions)
        handleBehavior(
            gestureBehavior.behaviors,
            identifer: identifier,
            transition: transition,
            index: index
        )
    }
    
    // MARK: Handle automated actions
    
    private func handlePagerProgress(
        _ automatedActions: [AutomatedAction],
        index: Binding<Int>
    ) {
        
        let duration = pagerState.pages[pagerState.pageIndex].delay
        
        if self.pagerState.inProgress && (self.pagerState.pageIndex < self.model.items.count) {
            
            if (self.pagerState.progress < 1) {
                self.pagerState.progress += Pager.timerTransition / duration
            }
            
            let automatedAction = automatedActions.first {
                let currentDuration = (self.pagerState.progress * duration).round(to: 2)
                return $0.delay == currentDuration
            }
            
            if let automatedAction = automatedAction  {
                handleActions(automatedAction.actions)
                handleBehavior(
                    automatedAction.behaviors,
                    identifer: automatedAction.identifier,
                    transition: .automated,
                    index: index
                )
            }

        }
    }
    
    // MARK: Utils methods
    
    private func goToNextPage(
        _ index: Binding<Int>,
        transition: PagerTransition? = nil,
        identifier: String? = nil,
        loop: Bool = false,
        dismiss: Bool = false
    ) {
        
        var nextIndex =  min(
            pagerState.pageIndex + 1,
            pagerState.pages.count - 1)
        
        if pagerState.isLastPage() {
            if loop == true { nextIndex = 0 }
            if dismiss { thomasEnvironment.dismiss() }
        }
        
        goToPage(
            index,
            identifier: identifier,
            transition: transition,
            pageIndex: nextIndex
        )
    }
    
    private func goToPreviousPage(
        _ index: Binding<Int>,
        transition: PagerTransition? = nil,
        identifier: String? = nil
    ) {
        let nextIndex = max(pagerState.pageIndex - 1, 0)
        goToPage(
            index,
            identifier: identifier,
            transition: transition,
            pageIndex: nextIndex
        )
    }
    
    private func goToPage(
        _ index: Binding<Int>,
        identifier: String?,
        transition: PagerTransition? = nil,
        pageIndex: Int
    ) {
        
        self.pagerState.resetProgress()
        
        guard pageIndex >= 0 else { return }
        guard pageIndex != index.wrappedValue else { return }
        guard pageIndex < self.model.items.count else { return }
        
        if let transition = transition {
            handlePagerTransition(
                transition,
                identifier: identifier,
                index: index,
                pageIndex: pageIndex
            )
        }
        
        withAnimation {
            index.wrappedValue = pageIndex
        }
    }
    
    private func handlePagerTransition(
        _ transition: PagerTransition,
        identifier: String?,
        index: Binding<Int>,
        pageIndex: Int
    ) {
        
        switch transition {
        case .swipe:
            thomasEnvironment.pageSwiped(
                self.pagerState,
                fromIndex: index.wrappedValue,
                toIndex: pageIndex,
                layoutState: layoutState
            )
            thomasEnvironment.pageGesture(
                identifier: identifier,
                layoutState: layoutState
            )
        case .automated:
            thomasEnvironment.pageAutomated(
                identifier: identifier,
                layoutState: layoutState
            )
        case .tap:
            thomasEnvironment.pageGesture(
                identifier: identifier,
                layoutState: layoutState
            )
        }
    }
    
    private func handleActions(
        _ actions: [ActionsPayload]?
    ) {
        if let actions = actions {
            actions.forEach { action in
                thomasEnvironment.runActions(action, layoutState: layoutState)
            }
        }
    }
    
    private func handleBehavior(
        _ behaviors: [ButtonClickBehavior]?,
        identifer: String?,
        transition: PagerTransition? = nil,
        index: Binding<Int>
    ) {
    
        guard let behaviors = behaviors else {
            return
        }
        
        if behaviors.contains(.dismiss) {
            thomasEnvironment.dismiss()
        }
        
        if behaviors.contains(.pagerNext) {
            goToNextPage(
                index,
                transition: transition,
                identifier: identifer
            )
        }
        
        if behaviors.contains(.pagerPrevious) {
            goToPreviousPage(
                index,
                transition: transition,
                identifier: identifer
            )
        }
        
        if behaviors.contains(.pagerNextOrDismiss) {
            goToNextPage(
                index,
                transition: transition,
                identifier: identifer,
                dismiss: true
            )
        }
        
        if behaviors.contains(.pagerNextOrFirst) {
            goToNextPage(
                index,
                transition: transition,
                identifier: identifer,
                loop: true
            )
        }
        
        if behaviors.contains(.pagerPause) {
            self.pagerState.pause()
        }
        
        if behaviors.contains(.pagerResume) {
            self.pagerState.resume()
        }
    }
    
    private func hasStoryNavigationBehavior(
        behaviors: [ButtonClickBehavior]?
    ) -> Bool {
        guard let behaviors = behaviors else {
            return false
        }
        
        return !behaviors.filter{ navigationAction.contains($0) }.isEmpty
    }
    
    private func earliestNavigationAction(
        _ automatedActions: [AutomatedAction]?
    ) -> AutomatedAction? {
        
        guard let automatedActions = automatedActions else {
            return nil
        }
        
        return automatedActions.first {
            hasStoryNavigationBehavior(behaviors: $0.behaviors) == true
        }
    }
    
    private func isRightToLeft() -> Bool {
        return (self.direction == .rightToLeft) ? true : false
    }
    
    private func reportPage(_ index: Int) {
        if self.lastIndex != index {
            if index == self.model.items.count - 1 {
                self.pagerState.completed = true
            }
            self.thomasEnvironment.pageViewed(
                self.pagerState,
                layoutState: layoutState
            )
            self.lastIndex = index

            // Run any actions set on the current page
            let page = self.model.items[index]
            self.thomasEnvironment.runActions(
                page.displayActions,
                layoutState: layoutState
            )
            
            let automatedAction = page.automatedActions?.first {
                $0.delay == 0.0
            }
            automatedAction?.actions?.forEach({ action in
                self.thomasEnvironment.runActions(
                    action,
                    layoutState: layoutState
                )
            })

        }
    }
    
}

extension Double {
    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
