/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine


struct Pager: View {

    private static let navigationAction: [ButtonClickBehavior] = [
        .dismiss,
        .cancel,
        .pagerNext,
        .pagerPrevious,
        .pagerNextOrFirst,
        .pagerNextOrDismiss
    ]

    private enum PageTransition {
        case gesture(identifier: String, reportingMetadata: AirshipJSON?)
        case automated(identifier: String, reportingMetadata: AirshipJSON?)
        case defaultSwipe
    }

    private enum SwipeDirection {
        case up
        case down
        case start
        case end
    }

    private static let flingSpeed: CGFloat = 150.0
    private static let offsetPercent: CGFloat = 0.50
    private static let timerTransition = 0.01

    @EnvironmentObject var formState: FormState
    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.isVisible) var isVisible
    @Environment(\.layoutState) var layoutState
    @Environment(\.layoutDirection) var layoutDirection

    let model: PagerModel
    let constraints: ViewConstraints

    @State var lastIndex = -1

    @GestureState private var translation: CGFloat = 0
    @GestureState private var isPressingDown: Bool = false

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
            .animation(.interactiveSpring(), value: index.wrappedValue)
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
                            delay: earliestNavigationAction($0.automatedActions)?.delay ?? 0.0,
                            automatedActions: $0.automatedActions?.compactMap({ automatedAction in
                                automatedAction.identifier
                            })
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
                .applyIf(self.model.isDefaultSwipeEnabled || self.model.hasGestureType(type: .swipe)) { view in
                    view.simultaneousGesture(makeSwipeGesture(size: metrics.size, index: index))
                }
                .applyIf(self.model.isDefaultSwipeEnabled) { view in
                    view.accessibilityScrollAction  { edge in
                        if (edge == Edge.leading) {
                            if (self.layoutDirection == .leftToRight) {
                                goToNextPage(index, transition: .defaultSwipe)
                            } else {
                                goToPreviousPage(index, transition: .defaultSwipe)
                            }
                        }

                        if (edge == Edge.trailing) {
                            if (self.layoutDirection == .leftToRight) {
                                goToPreviousPage(index, transition: .defaultSwipe)
                            } else {
                                goToNextPage(index, transition: .defaultSwipe)
                            }
                        }
                    }
                }
                .applyIf(self.model.hasGestureType(type: .hold)) { view in
                    view.simultaneousGesture(makeLongPressGesture())
                        .airshipOnChangeOf( isPressingDown) { value in
                            handleLongPress(isPressed: value, index: index)
                        }
                }
                .applyIf(self.model.hasGestureType(type: .tap)) { view in
                    view.addLocationTapGesture(
                        geometryProxy: metrics,
                        layoutDirection: layoutDirection
                    ) { locations in
                        handleTap(locations: locations, index: index)
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
    

    
#if !os(tvOS)
    private func makeSwipeGesture(
        size: CGSize,
        index: Binding<Int>
    ) -> some Gesture {
        return DragGesture(minimumDistance: 30)
            .updating(self.$translation) { value, state, _ in
                if (self.model.isDefaultSwipeEnabled) {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                let xVelocity = value.predictedEndLocation.x - value.location.x
                let yVelocity = value.predictedEndLocation.y - value.location.y
                let widhtOffset = value.translation.width / size.width
                let heightOffset = value.translation.height / size.height

                var swipeDirection: SwipeDirection? = nil
                if (abs(xVelocity) > abs(yVelocity)) {
                    if abs(xVelocity) >= Pager.flingSpeed {
                        if (xVelocity > 0) {
                            swipeDirection = (layoutDirection == .leftToRight) ? .start : .end
                        } else {
                            swipeDirection = (layoutDirection == .leftToRight) ? .end : .start
                        }
                    } else if abs(widhtOffset) >= Pager.offsetPercent {
                        if (widhtOffset > 0) {
                            swipeDirection = (layoutDirection == .leftToRight) ? .start : .end
                        } else {
                            swipeDirection = (layoutDirection == .leftToRight) ? .end : .start
                        }
                    }
                } else {
                    if abs(yVelocity) >= Pager.flingSpeed {
                        swipeDirection = (yVelocity > 0) ? .down : .up
                     } else if abs(heightOffset) >= Pager.offsetPercent {
                         swipeDirection = (heightOffset > 0) ? .down : .up
                     }
                }

                guard let swipeDirection = swipeDirection else {
                    return
                }


                switch(swipeDirection) {
                case .up:
                    handleSwipe(direction: .up, index: index)

                case .down:
                    handleSwipe(direction: .down, index: index)

                case .start:
                    if (self.model.isDefaultSwipeEnabled) {
                        goToPreviousPage(index, transition: .defaultSwipe)
                    }
                case .end:
                    if (self.model.isDefaultSwipeEnabled) {
                        goToNextPage(index, transition: .defaultSwipe)
                    }
                }
            }
    }
    
    private func makeLongPressGesture() -> some Gesture {
        return LongPressGesture(minimumDuration: 0.1)
            .sequenced(before: LongPressGesture(minimumDuration: .infinity))
            .updating($isPressingDown) { value, state, transaction in
                switch value {
                    case .second(true, nil):
                        state = true
                    default: break
                }
            }
    }
    
#endif
    
    /// Handle tap gesture
    /// Retrieve the first available gesture with a sorted location array to handle RTL
    private func handleTap(
        locations: [PagerGestureLocation],
        index: Binding<Int>
    ) {
        locations.forEach { location in
            self.model.retrieveGestures(type: PagerTapGesture.self)
                .filter { $0.location == location }
                .forEach { gesture in
                    handleGestureBehavior(
                        gesture.behavior,
                        transition: .gesture(
                            identifier: gesture.identifier,
                            reportingMetadata: gesture.reportingMetadata
                        ),
                        index: index
                    )
                }
        }
    }
    
    private func handleSwipe(
        direction: PagerGestureDirection,
        index: Binding<Int>
    ) {
        self.model.retrieveGestures(type: PagerDragGesture.self)
            .filter { $0.direction == direction }
            .forEach { gesture in
                handleGestureBehavior(
                    gesture.behavior,
                    transition: .gesture(
                        identifier: gesture.identifier,
                        reportingMetadata: gesture.reportingMetadata
                    ),
                    index: index
                )
            }
    }
    
    private func handleLongPress(isPressed: Bool, index: Binding<Int>) {
        self.model.retrieveGestures(type: PagerHoldGesture.self).forEach { gesture in
            let behavior = isPressed ? gesture.pressBehavior : gesture.releaseBehavior
            handleGestureBehavior(
                behavior,
                transition: .gesture(
                    identifier: gesture.identifier,
                    reportingMetadata: gesture.reportingMetadata
                ),
                index: index
            )
        }
    }
    
    private func handleGestureBehavior(
        _ gestureBehavior: PagerGestureBehavior,
        transition: PageTransition,
        index: Binding<Int>
    ) {
        handleBehavior(
            gestureBehavior.behaviors,
            transition: transition,
            index: index
        )
        handleActions(gestureBehavior.actions)
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
            
            // Check for any automated action past the current duration that have not been executed yet
            let automatedAction = automatedActions.first {
                let isExecuted = (self.pagerState.currentPage.automatedActionStatus[$0.identifier] == true)
                let isOlder = (self.pagerState.progress * duration) >= ($0.delay ?? 0.0)
                return !isExecuted && isOlder
            }
            
            if let automatedAction = automatedAction  {
                handleActions(automatedAction.actions)
                handleBehavior(
                    automatedAction.behaviors,
                    transition: .automated(
                        identifier: automatedAction.identifier,
                        reportingMetadata: automatedAction.reportingMetadata
                    ),
                    index: index
                )
                pagerState.markAutomatedActionExecuted(automatedAction.identifier)
            }

        }
    }
    
    // MARK: Utils methods
    
    private func goToNextPage(
        _ index: Binding<Int>,
        transition: PageTransition,
        loop: Bool = false,
        dismiss: Bool = false
    ) {
        
        if pagerState.isLastPage() {
            
            if loop == true {
                goToPage(
                    index,
                    transition: transition,
                    pageIndex: 0
                )
            }
            if dismiss { thomasEnvironment.dismiss() }
            
        } else {
            
            let nextIndex =  min(
                pagerState.pageIndex + 1,
                pagerState.pages.count - 1)
            goToPage(
                index,
                transition: transition,
                pageIndex: nextIndex
            )
            
        }
    }
    
    private func goToPreviousPage(
        _ index: Binding<Int>,
        transition: PageTransition
    ) {
        let nextIndex = max(pagerState.pageIndex - 1, 0)
        goToPage(
            index,
            transition: transition,
            pageIndex: nextIndex
        )
    }
    
    private func goToPage(
        _ index: Binding<Int>,
        transition: PageTransition,
        pageIndex: Int
    ) {
        
        self.pagerState.resetProgress()
        
        guard pageIndex >= 0 else { return }
        guard pageIndex != index.wrappedValue || self.pagerState.pages.count == 1 else { return }
        guard pageIndex < self.pagerState.pages.count else { return }
        
        handlePagerTransition(
            transition,
            index: index,
            pageIndex: pageIndex
        )
        
        withAnimation {
            index.wrappedValue = pageIndex
        }
    }
    
    private func handlePagerTransition(
        _ transition: PageTransition,
        index: Binding<Int>,
        pageIndex: Int
    ) {
        
        switch transition {
        case .defaultSwipe:
            thomasEnvironment.pageSwiped(
                self.pagerState,
                fromIndex: index.wrappedValue,
                toIndex: pageIndex,
                layoutState: layoutState
            )
        case .gesture(let identifier, let reportingMetadata):
            thomasEnvironment.pageGesture(
                identifier: identifier,
                reportingMetatda: reportingMetadata,
                layoutState: layoutState
            )
        case .automated(let identifier, let reportingMetadata):
            thomasEnvironment.pageAutomated(
                identifier: identifier,
                reportingMetatda: reportingMetadata,
                layoutState: layoutState
            )
        }
    }
    
    private func handleActions(_ actions: [ActionsPayload]?) {
        if let actions = actions {
            actions.forEach { action in
                thomasEnvironment.runActions(action, layoutState: layoutState)
            }
        }
    }
    
    private func handleBehavior(
        _ behaviors: [ButtonClickBehavior]?,
        transition: PageTransition,
        index: Binding<Int>
    ) {
        
        behaviors?.sorted { first, second in
            first.sortOrder < second.sortOrder
        }.forEach { behavior in
            
            switch(behavior) {
            case .dismiss:
                thomasEnvironment.dismiss()
                
            case .cancel:
                thomasEnvironment.dismiss()
                
            case .pagerNext:
                goToNextPage(index, transition: transition)
                
            case .pagerPrevious:
                goToPreviousPage(index, transition: transition)
                
            case .pagerNextOrDismiss:
                goToNextPage(index, transition: transition, dismiss: true)
                
            case .pagerNextOrFirst:
                goToNextPage(index, transition: transition, loop: true)
                
            case .pagerPause:
                pagerState.pause()
                
            case .pagerResume:
                pagerState.resume()
                
            case .formSubmit:
                let formState = formState.topFormState
                thomasEnvironment.submitForm(formState, layoutState: layoutState)
                formState.markSubmitted()
            }
        }
    }
    
    private func hasStoryNavigationBehavior(behaviors: [ButtonClickBehavior]?) -> Bool {
        guard let behaviors = behaviors else {
            return false
        }
        
        return !behaviors.filter{ Pager.navigationAction.contains($0) }.isEmpty
    }
    
    private func earliestNavigationAction(_ automatedActions: [AutomatedAction]?) -> AutomatedAction? {
        
        guard let automatedActions = automatedActions else {
            return nil
        }
        
        return automatedActions.first {
            hasStoryNavigationBehavior(behaviors: $0.behaviors) == true
        }
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
                $0.delay == nil || $0.delay == 0.0
            }
            
            if let automatedAction = automatedAction {
                handleActions(automatedAction.actions)
                pagerState.markAutomatedActionExecuted(automatedAction.identifier)
            }

        }
    }
}


fileprivate extension View {
    @ViewBuilder
    func addLocationTapGesture(
        geometryProxy: GeometryProxy,
        layoutDirection: LayoutDirection,
        action: @escaping ([PagerGestureLocation]) -> Void
    ) -> some View {
#if !os(tvOS)
        if #available(iOS 16.0, watchOS 9.0, *) {
            let pagerGestureEplorer = PagerGestureMapExplorer(
                CGRect(
                    x: 0,
                    y: 0,
                    width: geometryProxy.size.width,
                    height: geometryProxy.size.height
                )
            )

            self.simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        action(pagerGestureEplorer.location(layoutDirection: layoutDirection, forPoint: event.location))
                    }
            )
        } else {
            self
        }
#else
        self
#endif
    }
}

fileprivate extension PagerModel {
    var isDefaultSwipeEnabled: Bool {
        return disableSwipe != true && self.items.count > 1
    }

    func retrieveGestures<T: PagerGesture>(type: T.Type) -> [T] {
        guard let gestures = self.gestures else {
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

    func hasGestureType(type: PagerGestureType) -> Bool {
        guard let gestures = gestures else {
            return false
        }

        return gestures.contains(where: { gesture in
            switch(gesture) {
            case .swipeGesture(let gesture): return gesture.type == type
            case .tapGesture(let gesture): return gesture.type == type
            case .holdGesture(let gesture): return gesture.type == type
            }
        })
    }
}

