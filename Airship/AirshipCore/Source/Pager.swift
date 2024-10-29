/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

struct Pager: View {

    private enum PagerEvent {
        case gesture(identifier: String, reportingMetadata: AirshipJSON?)
        case automated(identifier: String, reportingMetadata: AirshipJSON?)
        case accessibilityAction(type: AccessibilityActionType, reportingMetadata: AirshipJSON?)
        case defaultSwipe(from: Int, to: Int)
    }

    // For debugging, set to true to force legacy pager behavior on iOS 17+
    private static let forceLegacyPager: Bool = false

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

    @State private var lastReportedIndex = -1
    @GestureState private var translation: CGFloat = 0
    @State private var size: CGSize?
    @State private var isVoiceOverRunning: Bool = false
    @State private var scrollPosition: Int?
    @State private var clearPagingRequestTask: Task<Void, Never>?
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    private var isLegacyPageSwipeEnabled: Bool {
        if #available(iOS 17.0, *) {
            return if Self.forceLegacyPager {
                self.model.isDefaultSwipeEnabled
            } else {
                false
            }
        }

        return self.model.isDefaultSwipeEnabled
    }

    private var shouldAddSwipeGesture: Bool {
        if isLegacyPageSwipeEnabled { return true }
        if self.model.containsGestures([.swipe]) { return true }
        return false
    }

    private var shouldAddA11ySwipeActions: Bool {
        if self.model.isDefaultSwipeEnabled { return true }
        if self.model.containsGestures([.swipe]) { return true }
        return false
    }


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
    func makePager() -> some View {
        if (self.model.items.count == 1) {
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
            model: self.model.items[0].view,
            constraints: constraints
        )
        .environment(\.isVisible, true)
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
            .airshipOnChangeOf(self.pagerState.pageRequest, initial: false) { value in
                guard let value else { return }
                let index = self.resolvePageRequest(value)

                self.pagerState.pageRequest = nil

                guard index != scrollPosition else {
                    return
                }

                withAnimation {
                    self.pagerState.setPageIndex(index)
                }
            }
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
        ScrollView (.horizontal) {
            LazyHStack(spacing: 0) {
                makePageViews(childConstraints: childConstraints, metrics: metrics)
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(self.pagerState.pageRequest != nil)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .scrollIndicators(.never)
        .onChange(of: scrollPosition, initial: false) { old, value in
            if let position = value, position != self.pagerState.pageIndex {
                handleEvents(.defaultSwipe(from: self.pagerState.pageIndex, to: position))
                self.pagerState.setPageIndex(position)
            }
        }
        .airshipOnChangeOf(self.pagerState.pageRequest, initial: false) { value in
            guard let value else { return }
            let index = self.resolvePageRequest(value)

            guard index != scrollPosition else {
                self.pagerState.pageRequest = nil
                return
            }

            self.pagerState.setPageIndex(index)

            withAnimation {
                self.scrollPosition = index
            }

            // This workarounds an issue that I found with scrollPosition(id:)
            // where if you animate the scrollPosition and touch fast enough
            // to interrupt the scroll behavior, the scrollPosition will
            // think its on the other page, but in reality its not. To prevent
            // this, we are disabling touch while we have a `self.pagerState.pageRequest`
            // and enabling it after 250 ms. And yes, I tried using the completion handler
            // on the animation but it was being called immediately no matter what I
            // did, probably due to some config on the scroll view.
            self.clearPagingRequestTask?.cancel()
            self.clearPagingRequestTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard
                    !Task.isCancelled,
                    self.pagerState.pageRequest == value
                else {
                    return
                }
                self.pagerState.pageRequest = nil
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

    private func resolvePageRequest(_ pageRequest: PageRequest) -> Int {
        return switch pageRequest {
        case .next:
            pagerState.nextPageIndex
        case .back:
            pagerState.previousPageIndex
        case .first:
            0
        }
    }

    @ViewBuilder
    private func makePageViews(childConstraints: ViewConstraints, metrics: GeometryProxy) -> some View {
        ForEach(0..<self.model.items.count, id: \.self) { i in
            VStack {
                ViewFactory.createView(
                    model: self.model.items[i].view,
                    constraints: childConstraints
                )
                .allowsHitTesting(self.isVisible && i == pagerState.pageIndex)
                .environment(\.isVisible, self.isVisible && i == pagerState.pageIndex)
                .environment(\.pageIndex, i)
                .accessibilityActionsCompat {
                    makeAccessibilityActions(pageItem: model.items[i])
                }
                .accessibilityHidden(!(self.isVisible && i == pagerState.pageIndex))
                .id(i)
            }
            .frame(
                width: metrics.size.width,
                height: metrics.size.height
            )
            .environment(
                \.isButtonActionsEnabled,
                 (!self.isLegacyPageSwipeEnabled || self.translation == 0)
            )
        }
    }

    @ViewBuilder
    private func makeAccessibilityActions(pageItem: PagerItem) -> some View {
        if let actions = pageItem.accessibilityActions {
            ForEach(actions) { accessibilityAction in
                Button {
                    handleEvents(
                        .accessibilityAction(
                            type: accessibilityAction.type,
                            reportingMetadata: accessibilityAction.reportingMetadata
                        )
                    )
                    handleActions(accessibilityAction.actions)
                    handleBehavior(accessibilityAction.behaviors)
                } label: {
                    let nameKey = accessibilityAction.localizedContentDescription?.descriptionKey
                    let fallback = accessibilityAction.localizedContentDescription?.fallbackDescription
                    let text = nameKey?.airshipLocalizedString(fallback: fallback) ?? "unknown" /// Action fallback description should always be defined
                    Text(text)
                }.accessibilityRemoveTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    var body: some View {
        makePager()
            .onReceive(pagerState.$pageIndex) { value in
                pagerState.pages = self.model.items.map {
                    PageState(
                        identifier: $0.identifier,
                        delay: $0.automatedActions?.earliestNavigationAction?.delay ?? 0.0,
                        automatedActions: $0.automatedActions?.compactMap({ automatedAction in
                            automatedAction.identifier
                        })
                    )
                }
                reportPage(value)
            }
            .onReceive(self.timer) { _ in
                onTimer()
            }
#if !os(watchOS)
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
                updateVoiceoverRunningState()
            }.onAppear {
                updateVoiceoverRunningState()
            }
#endif
#if !os(tvOS)
            .applyIf(self.shouldAddSwipeGesture) { view in
                view.simultaneousGesture(
                    makeSwipeGesture()
                )
            }
            .applyIf(self.shouldAddA11ySwipeActions) { view in
                view.accessibilityScrollAction  { edge in
                    let swipeDirection = PagerSwipeDirection.from(
                        edge: edge,
                        layoutDirection: self.layoutDirection
                    )
                    handleSwipe(direction: swipeDirection, isAccessibilityScrollAction: true)
                }
            }
            .applyIf(self.model.containsGestures([.hold, .tap])) { view in
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
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
    }

    // MARK: Handle Gesture

    
#if !os(tvOS)
    private func makeSwipeGesture() -> some Gesture {
        return DragGesture(minimumDistance: Self.minDragDistance)
            .updating(self.$translation) { value, state, _ in
                if (self.isLegacyPageSwipeEnabled) {
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
            self.model.retrieveGestures(type: PagerTapGesture.self)
                .filter { $0.location == location }
                .forEach { gesture in
                    handleBehavior(gesture.behavior.behaviors)
                    handleActions(gesture.behavior.actions)
                    handleEvents(
                        .gesture(
                            identifier: gesture.identifier,
                            reportingMetadata: gesture.reportingMetadata
                        )
                    )
                }
        }
    }

#endif

    // MARK: Utils methods

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

    private func handleSwipe(
        direction: PagerSwipeDirection,
        isAccessibilityScrollAction: Bool = false
    ) {
        switch(direction) {
        case .up: fallthrough
        case .down:
            self.model.retrieveGestures(type: PagerDragGesture.self)
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
                    handleBehavior(gesture.behavior.behaviors)
                    handleActions(gesture.behavior.actions)
                }
        case .start:
            guard
                !pagerState.isFirstPage,
                isAccessibilityScrollAction || self.isLegacyPageSwipeEnabled
            else {
                return
            }
            
            self.handleEvents(
                .defaultSwipe(
                    from: pagerState.pageIndex,
                    to: pagerState.previousPageIndex
                )
            )

            // Treat a11y swipes as page requests so they animate
            if isAccessibilityScrollAction {
                self.pagerState.pageRequest = .back
            } else {
                self.pagerState.setPageIndex(pagerState.previousPageIndex)
            }
        case .end:
            guard
                !pagerState.isLastPage,
                isAccessibilityScrollAction || self.isLegacyPageSwipeEnabled
            else {
                return
            }

            self.handleEvents(
                .defaultSwipe(
                    from: pagerState.pageIndex,
                    to: pagerState.nextPageIndex
                )
            )

            // Treat a11y swipes as page requests so they animate
            if isAccessibilityScrollAction {
                self.pagerState.pageRequest = .next
            } else {
                self.pagerState.setPageIndex(pagerState.nextPageIndex)
            }
        }
    }

    private func handleTouch(isPressed: Bool) {
        self.model.retrieveGestures(type: PagerHoldGesture.self).forEach { gesture in
            let behavior = isPressed ? gesture.pressBehavior : gesture.releaseBehavior
            if !isPressed {
                handleEvents(
                    .gesture(
                        identifier: gesture.identifier,
                        reportingMetadata: gesture.reportingMetadata
                    )
                )
            }
            handleBehavior(behavior.behaviors)
            handleActions(behavior.actions)
        }
    }

    private func onTimer() {
        guard !isVoiceOverRunning,
              let automatedActions = self.model.items[self.pagerState.pageIndex].automatedActions
        else {
            return
        }

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
                handleEvents(
                    .automated(
                        identifier: automatedAction.identifier,
                        reportingMetadata: automatedAction.reportingMetadata
                    )
                )
                handleActions(automatedAction.actions)
                handleBehavior(automatedAction.behaviors)
                pagerState.markAutomatedActionExecuted(automatedAction.identifier)
            }

        }
    }

    private func handleEvents(_ event: PagerEvent) {
        AirshipLogger.debug("Processing pager event: \(event)")

        switch event {
        case .defaultSwipe(let from, let to):
            thomasEnvironment.pageSwiped(
                self.pagerState,
                fromIndex: from,
                toIndex: to,
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
        case .accessibilityAction(type: _, reportingMetadata: _):
            /// TODO add accessibility action analytics event
            break
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
        _ behaviors: [ButtonClickBehavior]?
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
                pagerState.pageRequest = .next

            case .pagerPrevious:
                pagerState.pageRequest = .back

            case .pagerNextOrDismiss:
                if pagerState.isLastPage {
                    thomasEnvironment.dismiss()
                } else {
                    pagerState.pageRequest = .next
                }

            case .pagerNextOrFirst:
                if pagerState.isLastPage {
                    pagerState.pageRequest = .first
                } else {
                    pagerState.pageRequest = .next
                }

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

    private func reportPage(_ index: Int) {
        if self.lastReportedIndex != index {
            if index == self.model.items.count - 1 {
                self.pagerState.completed = true
            }
            self.thomasEnvironment.pageViewed(
                self.pagerState,
                layoutState: layoutState
            )
            self.lastReportedIndex = index

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
