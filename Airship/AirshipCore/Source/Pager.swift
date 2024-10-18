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
        case accessibilityAction(type: AccessibilityActionType, reportingMetadata: AirshipJSON?)
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
    private static let timerTransition: CGFloat = 0.01
    private static let minDragDistance: CGFloat = 60.0

    static let animationSpeed: TimeInterval = 0.75

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
    @State var size: CGSize?

    @State private var isVoiceOverRunning: Bool = false

    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(
        model: PagerModel,
        constraints: ViewConstraints
    ) {
        self.model = model
        self.constraints = constraints
        self.timer = Timer.publish(
            every: Pager.timerTransition,
            on: .main,
            in: .default
        )
        .autoconnect()
    }

    @ViewBuilder
    private func makePageViews(index: Binding<Int>, childConstraints: ViewConstraints, metrics: GeometryProxy) -> some View {
        ForEach(0..<self.model.items.count, id: \.self) { i in
            VStack {
                ViewFactory.createView(
                    model: self.model.items[i].view,
                    constraints: childConstraints
                )
                .allowsHitTesting(self.isVisible && i == index.wrappedValue)
                .environment(
                    \.isVisible,
                     self.isVisible && i == index.wrappedValue
                )
                .environment(\.pageIndex, i)
                .applyIf(true) { view in
                    if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                        view.accessibilityActions {
                            makeAccessibilityActions(accessibilityActions: model.items[i].accessibilityActions, index: index)
                        }
                    } else {
                        /// Applying these action
                        view
                    }
                }
                .accessibilityHidden(!(self.isVisible && i == index.wrappedValue))
            }
            .frame(
                width: metrics.size.width,
                height: metrics.size.height
            )
            .environment(\.isButtonActionsEnabled, self.translation == 0)
        }
    }

    @ViewBuilder
    private func makeAccessibilityActions(accessibilityActions: [AccessibilityAction]?, index: Binding<Int>) -> some View {
        if let actions = accessibilityActions {
            ForEach(actions) { accessibilityAction in
                Button {
                    handleActions(accessibilityAction.actions)
                    handleBehavior(accessibilityAction.behaviors, transition: .accessibilityAction(type: accessibilityAction.type, reportingMetadata: accessibilityAction.reportingMetadata), index: index)
                } label: {
                    Text(accessibilityActionContentDescription(action: accessibilityAction))
                }.accessibilityRemoveTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    func makePager(index: Binding<Int>) -> some View {
        if (self.model.items.count == 1) {
            ViewFactory.createView(
                model: self.model.items[0].view,
                constraints: constraints
            )
            .environment(\.isVisible, true)
            .constraints(constraints)
            .airshipMeasureView(self.$size)
        } else {
            GeometryReader { metrics in
                let childConstraints = ViewConstraints(
                    width: metrics.size.width,
                    height: metrics.size.height,
                    isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
                    isVerticalFixedSize: self.constraints.isVerticalFixedSize,
                    safeAreaInsets: self.constraints.safeAreaInsets
                )

                VStack {
                    HStack(spacing: 0) {
                        makePageViews(index: index, childConstraints: childConstraints, metrics: metrics)
                    }
                    .offset(x: -(metrics.size.width * CGFloat(index.wrappedValue)))
                    .offset(x: calcDragOffset(index: index.wrappedValue))
                    .animation(.interactiveSpring(duration: Pager.animationSpeed), value: index.wrappedValue)
                }
                .frame(
                    width: metrics.size.width,
                    height: metrics.size.height,
                    alignment: .leading
                )
                .clipped()
                .onAppear {
                    size = metrics.size
                }
                .airshipOnChangeOf(metrics.size) { newSize in
                    size = newSize
                }
            }
        }
    }

    private var containsDragGestures: Bool {
        if self.model.isDefaultSwipeEnabled {
            return true
        }

        let dragGestures = self.model.retrieveGestures(type: PagerDragGesture.self)
        return !dragGestures.isEmpty
    }

    private func accessibilityActionContentDescription(action: AccessibilityAction) -> String {
        let nameKey = action.localizedContentDescription?.descriptionKey
        let fallback = action.localizedContentDescription?.fallbackDescription

        return nameKey?.airshipLocalizedString(fallback: fallback) ?? "unknown" /// Action fallback description should always be defined
    }

    private func updateVoiceoverRunningState() {
        #if !os(watchOS)
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        #else
            isVoiceOverRunning = false
        #endif

        /// Pause pager when voiceover is active
        if isVoiceOverRunning {
            pagerState.pause()
        } else {
            pagerState.resume()
        }
    }

    @ViewBuilder
    var body: some View {
        let index = Binding<Int>(
            get: { self.pagerState.pageIndex },
            set: { self.pagerState.pageIndex = $0 }
        )

        makePager(index: index)
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
                if let automatedActions = self.model.items[self.pagerState.pageIndex].automatedActions, !isVoiceOverRunning {
                    handlePagerProgress(automatedActions, index: index)
                }
            }
#if !os(watchOS)
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
                updateVoiceoverRunningState()
            }.onAppear {
                updateVoiceoverRunningState()
            }
#endif
#if !os(tvOS)
            .applyIf(self.containsDragGestures) { view in
                view.simultaneousGesture(
                    makeSwipeGesture(index: index)
                )
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
            .applyIf(true) { view in
                if #available(iOS 16.0, macOS 13.0, watchOS 9.0, visionOS 1.0, *) {
                    view.onTouch { isPressed in
                            handleTouch(isPressed: isPressed, index: index)
                        }
                        .simultaneousGesture(makeTapGesture(index: index))
                } else {
                    view.onTouch { isPressed in
                        handleTouch(isPressed: isPressed, index: index)
                    }
                }
            }
#endif
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
    }

    // MARK: Handle Gesture

    
#if !os(tvOS)
    private func makeSwipeGesture(
        index: Binding<Int>
    ) -> some Gesture {
        return DragGesture(minimumDistance: Self.minDragDistance)
            .updating(self.$translation) { value, state, _ in
                if (self.model.isDefaultSwipeEnabled) {
                    if (abs(value.translation.width) > Self.minDragDistance) {
                        state = if (value.translation.width > 0) {
                            value.translation.width - Self.minDragDistance
                        } else {
                            value.translation.width + Self.minDragDistance
                        }
                    } else {
                        state = 0
                    }
                }
            }
            .onEnded { value in
                guard let size = self.size else {
                    return
                }

                let xVelocity = value.predictedEndLocation.x - value.location.x
                let yVelocity = value.predictedEndLocation.y - value.location.y
                let widthOffset = value.translation.width / size.width
                let heightOffset = value.translation.height / size.height

                var swipeDirection: SwipeDirection? = nil
                if (abs(xVelocity) > abs(yVelocity)) {
                    if abs(xVelocity) >= Pager.flingSpeed {
                        if (xVelocity > 0) {
                            swipeDirection = (layoutDirection == .leftToRight) ? .start : .end
                        } else {
                            swipeDirection = (layoutDirection == .leftToRight) ? .end : .start
                        }
                    } else if abs(widthOffset) >= Pager.offsetPercent {
                        if (widthOffset > 0) {
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
                        handleEvents(.defaultSwipe, index: index, pageIndex: getPreviousPageIndex())
                        /// Call order matters because goToPreviousPage method decrements index
                        goToPreviousPage(index, transition: .defaultSwipe)
                    }
                case .end:
                    if (self.model.isDefaultSwipeEnabled) {
                        handleEvents(.defaultSwipe, index: index, pageIndex: getNextPageIndex())
                        /// Call order matters because goToNextPage method increments index
                        goToNextPage(index, transition: .defaultSwipe)
                    }
                }
            }
    }
    

    @available(iOS 16.0, macOS 13.0, watchOS 9.0, visionOS 1.0, *)
    @available(tvOS, unavailable)
    private func makeTapGesture(index: Binding<Int>) -> some Gesture {
        return SpatialTapGesture()
            .onEnded { event in
                guard let size = size else {
                    return
                }

                let pagerGestureExplorer = PagerGestureMapExplorer(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: size.width,
                        height: size.height
                    )
                )

                handleTap(
                    locations: pagerGestureExplorer.location(
                        layoutDirection: layoutDirection,
                        forPoint: event.location
                    ),
                    index: index
                )
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
    
    private func handleTouch(isPressed: Bool, index: Binding<Int>) {
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

    private func handleAccessibilityAction(
        accessibilityAction: AccessibilityAction,
        transition: PageTransition,
        index: Binding<Int>
    ) {
        handleBehavior(
            accessibilityAction.behaviors,
            transition: transition,
            index: index
        )
        handleActions(accessibilityAction.actions)
        handleEvents(transition, index: index, pageIndex: pagerState.pageIndex)
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
        handleEvents(transition, index: index, pageIndex: pagerState.pageIndex)
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

    private func getNextPageIndex() -> Int {
        return min(
            pagerState.pageIndex + 1,
            pagerState.pages.count - 1)
    }

    private func getPreviousPageIndex() -> Int {
        return max(pagerState.pageIndex - 1, 0)
    }

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
            goToPage(
                index,
                transition: transition,
                pageIndex: getNextPageIndex()
            )
        }
    }
    
    private func goToPreviousPage(
        _ index: Binding<Int>,
        transition: PageTransition
    ) {
        goToPage(
            index,
            transition: transition,
            pageIndex:  getPreviousPageIndex()
        )
    }
    
    private func goToPage(
        _ index: Binding<Int>,
        transition: PageTransition,
        pageIndex: Int
    ) {
        
        self.pagerState.preparePageChange()

        guard pageIndex >= 0 else { return }
        guard pageIndex != index.wrappedValue || self.pagerState.pages.count == 1 else { return }
        guard pageIndex < self.pagerState.pages.count else { return }

        index.wrappedValue = pageIndex
    }
    
    private func handleEvents(
        _ transition: PageTransition,
        index: Binding<Int>,
        pageIndex: Int
    ) {
        switch transition {
        case .defaultSwipe:
            AirshipLogger.debug("Transition type: Default Swipe from index \(index.wrappedValue) to \(pageIndex)")
            thomasEnvironment.pageSwiped(
                self.pagerState,
                fromIndex: index.wrappedValue,
                toIndex: pageIndex,
                layoutState: layoutState
            )
        case .gesture(let identifier, let reportingMetadata):
            AirshipLogger.debug("Transition type: Gesture with identifier \(identifier)")
            thomasEnvironment.pageGesture(
                identifier: identifier,
                reportingMetatda: reportingMetadata,
                layoutState: layoutState
            )
        case .automated(let identifier, let reportingMetadata):
            AirshipLogger.debug("Transition type: Automated with identifier \(identifier)")
            thomasEnvironment.pageAutomated(
                identifier: identifier,
                reportingMetatda: reportingMetadata,
                layoutState: layoutState
            )
        case .accessibilityAction(type: let type, reportingMetadata: _):
            AirshipLogger.debug("Transition type: accessibility action with type \(type)")
            /// TODO add accessibility action analytics event
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


    private func calcDragOffset(index: Int) -> CGFloat {
        var dragOffSet = self.translation
        if index <= 0 {
            dragOffSet = min(dragOffSet, 0)
        } else if index >= self.model.items.count - 1 {
            dragOffSet = max(dragOffSet, 0)
        }

        return dragOffSet
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
