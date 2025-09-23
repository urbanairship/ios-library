/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
struct Pager: View {

    private enum PagerEvent {
        case gesture(identifier: String, reportingMetadata: AirshipJSON?)
        case automated(identifier: String, reportingMetadata: AirshipJSON?)
        case accessibilityAction(ThomasAccessibilityAction)
        case defaultSwipe(PagerState.NavigationResult)
    }

    // For debugging, set to true to force legacy pager behavior on iOS 17+
    private static let forceLegacyPager: Bool = false

    private static let timerTransition: CGFloat = 0.01
    private static let minDragDistance: CGFloat = 60.0
    static let animationSpeed: TimeInterval = 0.75

    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var thomasState: ThomasState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.isVisible) var isVisible
    @Environment(\.layoutState) var layoutState
    @Environment(\.layoutDirection) var layoutDirection
    @Environment(\.isVoiceOverRunning) var isVoiceOverRunning

    let info: ThomasViewInfo.Pager
    let constraints: ViewConstraints

    @State private var lastReportedIndex = -1
    @GestureState private var translation: CGFloat = 0
    @State private var size: CGSize?
    @State private var scrollPosition: String?
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    private var isLegacyPageSwipeEnabled: Bool {
        if #available(iOS 17.0, *) {
            return if Self.forceLegacyPager {
                self.info.isDefaultSwipeEnabled
            } else {
                false
            }
        }

        return self.info.isDefaultSwipeEnabled
    }

    private var shouldAddSwipeGesture: Bool {
        if isLegacyPageSwipeEnabled { return true }
        if self.info.containsGestures([.swipe]) { return true }
        return false
    }

    private var shouldAddA11ySwipeActions: Bool {
        if self.info.isDefaultSwipeEnabled { return true }
        if self.info.containsGestures([.swipe]) { return true }
        return false
    }

    init(
        info: ThomasViewInfo.Pager,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
        self.timer = Timer.publish(
            every: Pager.timerTransition,
            on: .main,
            in: .default
        )
        .autoconnect()
    }

    @ViewBuilder
    func makePager() -> some View {
        if (pagerState.pageItems.count == 1) {
            self.makeSinglePagePager()
        } else {
            GeometryReader { metrics in
                let childConstraints = ViewConstraints(
                    width: metrics.size.width,
                    height: metrics.size.height,
                    isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
                    isVerticalFixedSize: self.constraints.isVerticalFixedSize,
                    safeAreaInsets: self.constraints.safeAreaInsets
                )

                if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
                    if (Self.forceLegacyPager) {
                        makeLegacyPager(childConstraints: childConstraints, metrics: metrics)
                    } else {
                        makeScrollViewPager(childConstraints: childConstraints, metrics: metrics)
                    }
                } else {
                    makeLegacyPager(childConstraints: childConstraints, metrics: metrics)
                }
            }
        }
    }

    @ViewBuilder
    func makeSinglePagePager() -> some View {
        ViewFactory.createView(
            pagerState.pageItems[0].view,
            constraints: constraints
        )
        .environment(\.isVisible, true)
        .environment(
            \.pageIdentifier,
             pagerState.pageItems[0].identifier
        )
        .constraints(constraints)
        .airshipMeasureView(self.$size)
    }

    @ViewBuilder
    func makeLegacyPager(childConstraints: ViewConstraints, metrics: GeometryProxy) -> some View {
        VStack {
            HStack(spacing: 0) {
                makePageViews(childConstraints: childConstraints, metrics: metrics)
            }
            .offset(x: -(metrics.size.width * CGFloat(pagerState.pageIndex)))
            .offset(x: calcDragOffset(index: pagerState.pageIndex))
            .animation(.interactiveSpring(duration: Pager.animationSpeed), value: pagerState.pageIndex)
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

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @ViewBuilder
    func makeScrollViewPager(childConstraints: ViewConstraints, metrics: GeometryProxy) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                makePageViews(childConstraints: childConstraints, metrics: metrics)
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(self.info.properties.disableSwipe == true || self.pagerState.isScrollingDisabled)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .scrollIndicators(.never)
        .airshipOnChangeOf(scrollPosition ?? "", initial: false) { value in
            guard !value.isEmpty, value != self.pagerState.currentPageId else {
                return
            }

            let result = self.pagerState.navigateToPage(id: value)
            if let result {
                handleEvents(.defaultSwipe(result))
            }
        }
        .frame(
            width: metrics.size.width,
            height: metrics.size.height,
            alignment: .leading
        )
        .onAppear {
            size = metrics.size
        }
        .airshipOnChangeOf(metrics.size) { newSize in
            size = newSize
        }
    }

    @ViewBuilder
    private func makePageViews(childConstraints: ViewConstraints, metrics: GeometryProxy) -> some View {
        ForEach(0..<pagerState.pageItems.count, id: \.self) { index in
            VStack {
                ViewFactory.createView(
                    pagerState.pageItems[index].view,
                    constraints: childConstraints
                )
                .allowsHitTesting(
                    self.isVisible && pagerState.pageItems[index].identifier == pagerState.currentPageId
                )
                .environment(
                    \.isVisible,
                     self.isVisible && pagerState.pageItems[index].identifier == pagerState.currentPageId
                )
                .environment(
                    \.pageIdentifier,
                     pagerState.pageItems[index].identifier
                )
                .accessibilityActions {
                    makeAccessibilityActions(
                        pageItem: pagerState.pageItems[index]
                    )
                }
                .accessibilityHidden(
                    !(
                        self.isVisible && pagerState.pageItems[index].identifier == pagerState.currentPageId
                    )
                )
            }
            .frame(
                width: metrics.size.width,
                height: metrics.size.height
            )
            .environment(
                \.isButtonActionsEnabled,
                 (!self.isLegacyPageSwipeEnabled || self.translation == 0)
            )
            .id(pagerState.pageItems[index].identifier)
        }
    }

    @ViewBuilder
    private func makeAccessibilityActions(pageItem: ThomasViewInfo.Pager.Item) -> some View {
        if let actions = pageItem.accessibilityActions {
            ForEach(0..<actions.count, id: \.self) { i in
                let action = actions[i]
                Button {
                    handleEvents(.accessibilityAction(action))
                    self.process(
                        behaviors: action.properties.behaviors,
                        actions: action.properties.actions
                    )
                } label: {
                    Text(
                        action.accessible.resolveContentDescription ?? "unknown"
                    )
                }
                .accessibilityRemoveTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        makePager()
            .onAppear(perform: attachToPagerState)
            .airshipOnChangeOf(pagerState.pageIndex, initial: true) { value in
                guard value >= 0, value < pagerState.pageItems.count else {
                    return
                }

                reportPage(value)

                let newIdentifier = pagerState.pageItems[value].identifier
                guard newIdentifier != scrollPosition else { return }

                withAnimation {
                    scrollPosition = newIdentifier
                }
            }
            .airshipOnChangeOf(pagerState.completed) { completed in
                guard completed else { return }
                self.thomasEnvironment.pagerCompleted(
                    pagerState: pagerState,
                    layoutState: layoutState
                )
            }
            .onReceive(self.timer) { _ in
                onTimer()
            }

#if !os(tvOS)
            .airshipApplyIf(self.shouldAddSwipeGesture) { view in
                view.simultaneousGesture(
                    makeSwipeGesture()
                )
            }
            .airshipApplyIf(self.shouldAddA11ySwipeActions) { view in
                view.accessibilityScrollAction  { edge in
                    let swipeDirection = PagerSwipeDirection.from(
                        edge: edge,
                        layoutDirection: self.layoutDirection
                    )
                    handleSwipe(direction: swipeDirection, isAccessibilityScrollAction: true)
                }
            }
            .airshipApplyIf(self.info.containsGestures([.hold, .tap])) { view in
                view.addPagerTapGesture(
                    onTouch: { isPressed in
                        handleTouch(isPressed: isPressed)
                    },
                    onTap: { location in
                        handleTap(tapLocation: location)
                    }
                )
            }
#endif
            .constraints(constraints)
            .thomasCommon(self.info)
            .airshipGeometryGroupCompat()
    }

    // MARK: Handle Gesture


#if !os(tvOS)
    private func makeSwipeGesture() -> some Gesture {
        return DragGesture(minimumDistance: Self.minDragDistance)
            .updating(self.$translation) { value, state, _ in
                guard self.isLegacyPageSwipeEnabled else {
                    return
                }

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
            .onEnded { value in
                guard
                    let size = self.size,
                    let swipeDirection = PagerSwipeDirection.from(
                        dragValue: value,
                        size: size,
                        layoutDirection: layoutDirection
                    )
                else {
                    return
                }

                handleSwipe(direction: swipeDirection)
            }
    }

    private func handleTap(tapLocation: CGPoint)  {
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

        let locations = pagerGestureExplorer.location(
            layoutDirection: layoutDirection,
            forPoint: tapLocation
        )

        locations.forEach { location in
            self.info.retrieveGestures(type: ThomasViewInfo.Pager.Gesture.Tap.self)
                .filter { $0.location == location }
                .forEach { gesture in
                    handleEvents(
                        .gesture(
                            identifier: gesture.identifier,
                            reportingMetadata: gesture.reportingMetadata
                        )
                    )

                    self.process(
                        behaviors: gesture.behavior.behaviors,
                        actions: gesture.behavior.actions
                    )
                }
        }
    }

#endif

    // MARK: Utils methods

    private func attachToPagerState() {
        pagerState.setPagesAndListenForUpdates(
            pages: info.properties.items,
            thomasState: thomasState,
            swipeDisableSelectors: info.properties.disableSwipePredicate
        )
    }

    private func handleSwipe(
        direction: PagerSwipeDirection,
        isAccessibilityScrollAction: Bool = false
    ) {
        switch(direction) {
        case .up: fallthrough
        case .down:
            self.info.retrieveGestures(type: ThomasViewInfo.Pager.Gesture.Swipe.self)
                .filter {
                    if ($0.direction == .up && direction == .up) {
                        return true
                    }

                    if ($0.direction == .down && direction == .down) {
                        return true
                    }

                    return false
                }
                .forEach { gesture in
                    handleEvents(
                        .gesture(
                            identifier: gesture.identifier,
                            reportingMetadata: gesture.reportingMetadata
                        )
                    )
                    self.process(
                        behaviors: gesture.behavior.behaviors,
                        actions: gesture.behavior.actions
                    )
                }
        case .start:
            guard
                !pagerState.isFirstPage, self.pagerState.canGoBack,
                isAccessibilityScrollAction || self.isLegacyPageSwipeEnabled
            else {
                return
            }

            // Treat a11y swipes as page requests so they animate
            if let result = pagerState.process(request: .back) {
                self.handleEvents(.defaultSwipe(result))
            }
        case .end:
            guard
                !pagerState.isLastPage,
                isAccessibilityScrollAction || self.isLegacyPageSwipeEnabled
            else {
                return
            }

            // Treat a11y swipes as page requests so they animate
            if let result = pagerState.process(request: .next) {
                self.handleEvents(.defaultSwipe(result))
            }
        }
    }

    private func handleTouch(isPressed: Bool) {
        self.info.retrieveGestures(type: ThomasViewInfo.Pager.Gesture.Hold.self).forEach { gesture in
            let behavior = isPressed ? gesture.pressBehavior : gesture.releaseBehavior
            if !isPressed {
                handleEvents(
                    .gesture(
                        identifier: gesture.identifier,
                        reportingMetadata: gesture.reportingMetadata
                    )
                )
            }

            self.process(
                behaviors: behavior.behaviors,
                actions: behavior.actions
            )
        }
    }

    private func onTimer() {
        guard !isVoiceOverRunning,
              let automatedActions = self.pagerState.pageItems[self.pagerState.pageIndex].automatedActions
        else {
            return
        }

        let duration = self.pagerState.pageStates[pagerState.pageIndex].delay

        if self.pagerState.inProgress && (self.pagerState.pageIndex < pagerState.pageItems.count) {
            if (self.pagerState.progress < 1) {
                self.pagerState.progress += Pager.timerTransition / duration
            }

            // Check for any automated action past the current duration that have not been executed yet
            automatedActions.filter {
                let isExecuted = (self.pagerState.currentPageState.automatedActionStatus[$0.identifier] == true)
                let isOlder = (self.pagerState.progress * duration) >= ($0.delay ?? 0.0)
                return !isExecuted && isOlder
            }.forEach { action in
                self.processAutomatedAction(action)
            }
        }
    }

    private func processAutomatedAction(_ automatedAction: ThomasAutomatedAction) {
        self.handleEvents(
            .automated(
                identifier: automatedAction.identifier,
                reportingMetadata: automatedAction.reportingMetadata
            )
        )

        self.process(
            behaviors: automatedAction.behaviors,
            actions: automatedAction.actions
        )

        self.pagerState.markAutomatedActionExecuted(automatedAction.identifier)
    }

    private func process(
        stateActions: [ThomasStateAction]? = nil,
        behaviors: [ThomasButtonClickBehavior]? = nil,
        actions: [ThomasActionsPayload]? = nil
    ) {
        Task { @MainActor in
            // Handle state first
            if let stateActions {
                thomasState.processStateActions(stateActions)

                // Workaround: Allows state to propagate before handling behaviors
                await Task.yield()
            }

            // Behaviors
            behaviors?.sortedBehaviors.forEach { behavior in
                switch(behavior) {
                case .dismiss:
                    self.thomasEnvironment.dismiss(layoutState: layoutState)

                case .cancel:
                    self.thomasEnvironment.dismiss(cancel: true, layoutState: layoutState)

                case .pagerNext:
                    self.pagerState.process(request: .next)

                case .pagerPrevious:
                    self.pagerState.process(request: .back)

                case .pagerNextOrDismiss:
                    if pagerState.isLastPage {
                        self.thomasEnvironment.dismiss()
                    } else {
                        self.pagerState.process(request: .next)
                    }

                case .pagerNextOrFirst:
                    if self.pagerState.isLastPage {
                        self.pagerState.process(request: .first)
                    } else {
                        self.pagerState.process(request: .next)
                    }

                case .pagerPause:
                    self.pagerState.pause()

                case .pagerResume:
                    self.pagerState.resume()

                case .formSubmit, .formValidate:
                    // not supported
                    break
                }
            }

            // Actions
            if let actions = actions {
                actions.forEach { action in
                    self.thomasEnvironment.runActions(action, layoutState: layoutState)
                }
            }
        }
    }

    private func handleEvents(_ event: PagerEvent) {
        AirshipLogger.debug("Processing pager event: \(event)")

        switch event {
        case .defaultSwipe(let navigationResult):
            if let from = navigationResult.fromPage {
                thomasEnvironment.pageSwiped(
                    pagerState: self.pagerState,
                    from: from,
                    to: navigationResult.toPage,
                    layoutState: layoutState
                )
            }

        case .gesture(let identifier, let reportingMetadata):
            thomasEnvironment.pageGesture(
                identifier: identifier,
                reportingMetadata: reportingMetadata,
                layoutState: layoutState
            )
        case .automated(let identifier, let reportingMetadata):
            thomasEnvironment.pageAutomated(
                identifier: identifier,
                reportingMetadata: reportingMetadata,
                layoutState: layoutState
            )
        case .accessibilityAction(_):
            /// TODO add accessibility action analytics event
            break
        }
    }

    private func reportPage(_ index: Int) {
        guard self.lastReportedIndex != index, !pagerState.pageItems.isEmpty else {
            return
        }
        
        self.thomasEnvironment.pageViewed(
            pagerState: self.pagerState,
            pageInfo: self.pagerState.pageInfo(index: index),
            layoutState: layoutState
        )
        self.lastReportedIndex = index
        
#if !os(watchOS)
        // Announce page change to VoiceOver
        if isVoiceOverRunning && lastReportedIndex >= 0 {
            // Use layoutChanged to force VoiceOver to re-scan the page for focusable elements
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
        }
#endif

        // Run any actions set on the current page
        let page = pagerState.pageItems[index]

        let displayActions: [ThomasActionsPayload]? = if let actions = page.displayActions {
            [actions]
        } else {
            nil
        }

        self.process(
            stateActions: page.stateActions,
            actions: displayActions
        )

        // Process any automated navigation actions
        onTimer()
    }

    private func calcDragOffset(index: Int) -> CGFloat {
        var dragOffSet = self.translation
        if index <= 0 {
            dragOffSet = min(dragOffSet, 0)
        } else if index >= pagerState.pageItems.count - 1 {
            dragOffSet = max(dragOffSet, 0)
        }

        return dragOffSet
    }
}

