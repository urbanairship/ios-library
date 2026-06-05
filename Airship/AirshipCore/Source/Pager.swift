/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

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

    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var asyncViewState: ThomasAsyncViewState

    @Environment(\.isVisible) private var isVisible
    @Environment(\.layoutState) private var layoutState
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning
#if !os(tvOS) && !os(watchOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

    private let info: ThomasViewInfo.Pager
    private let constraints: ViewConstraints

    @State private var lastReportedPageID: String?
    @State private var hasReportedCompleted: Bool = false
    @GestureState private var translation: CGFloat = 0
    @State private var size: CGSize?
    @State private var scrollPosition: String?
    @State private var pageHeights: [String: CGFloat] = [:]
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
        if isVoiceOverRunning {
            return false
        }
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
        } else if constraints.height == nil {
            self.makeAutoHeightPager()
        } else {
            self.makeMultiPagePager()
        }
    }

    @ViewBuilder
    private func makeAutoHeightPager() -> some View {
        let currentPageHeight = pageHeights[pagerState.currentPageId ?? ""]
        let childConstraints = ViewConstraints(
            width: constraints.width,
            height: nil,
            isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
            isVerticalFixedSize: self.constraints.isVerticalFixedSize,
            safeAreaInsets: self.constraints.safeAreaInsets
        )

        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
           !Self.forceLegacyPager {
            makeScrollViewPager(
                childConstraints: childConstraints,
                width: constraints.width,
                height: currentPageHeight
            )
            .fixedSize(horizontal: false, vertical: true)
            .airshipMeasureView(self.$size)
        } else {
            makeLegacyPager(
                childConstraints: childConstraints,
                width: constraints.width,
                height: currentPageHeight
            )
            .fixedSize(horizontal: false, vertical: true)
            .airshipMeasureView(self.$size)
        }
    }

    @ViewBuilder
    private func makeMultiPagePager() -> some View {
        GeometryReader { metrics in
            let width = metrics.size.width.safeValue
            let height = metrics.size.height.safeValue
            let childConstraints = ViewConstraints(
                width: width,
                height: height,
                isHorizontalFixedSize: self.constraints.isHorizontalFixedSize,
                isVerticalFixedSize: self.constraints.isVerticalFixedSize,
                safeAreaInsets: self.constraints.safeAreaInsets
            )

            if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
                if (Self.forceLegacyPager) {
                    makeLegacyPager(childConstraints: childConstraints, width: width, height: height)
                } else {
                    makeScrollViewPager(childConstraints: childConstraints, width: width, height: height)
                }
            } else {
                makeLegacyPager(childConstraints: childConstraints, width: width, height: height)
            }
        }
        .airshipMeasureView(self.$size)
    }

    @ViewBuilder
    private func makeSinglePagePager() -> some View {
        ViewFactory.createView(
            pagerState.pageItems[0].view,
            constraints: constraints
        )
        .environment(\.isVisible, self.isVisible)
        .environment(
            \.pageIdentifier,
             pagerState.pageItems[0].identifier
        )
        .constraints(constraints)
        .airshipMeasureView(self.$size)
    }

    @ViewBuilder
    private func makeLegacyPager(childConstraints: ViewConstraints, width: CGFloat?, height: CGFloat?) -> some View {
        VStack {
            HStack(spacing: 0) {
                makePageViews(
                    childConstraints: childConstraints,
                    width: width,
                    height: height,
                    isLegacyPager: true
                )
            }
            .offset(x: -((width ?? 0) * CGFloat(pagerState.pageIndex)))
            .offset(x: calcDragOffset(index: pagerState.pageIndex))
            .animation(.interactiveSpring(duration: Pager.animationSpeed), value: pagerState.pageIndex)
        }
        .frame(
            width: width,
            height: height,
            alignment: .leading
        )
        .clipped()
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    @ViewBuilder
    private func makeScrollViewPager(childConstraints: ViewConstraints, width: CGFloat?, height: CGFloat?) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                makePageViews(
                    childConstraints: childConstraints,
                    width: width,
                    height: height,
                    isLegacyPager: false
                )
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(self.info.properties.disableSwipe == true || self.pagerState.isScrollingDisabled)
        .allowsHitTesting(!pagerState.isNavigationInProgress)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .scrollIndicators(.never)
        .accessibilityElement(children: .contain)
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
            width: width,
            height: height,
            alignment: .leading
        )
#if !os(tvOS) && !os(watchOS)
        .id(verticalSizeClass)
#endif
    }

    @ViewBuilder
    private func makePageView(
        for index: Int,
        childConstraints: ViewConstraints,
        width: CGFloat?,
        height: CGFloat?,
        isLegacyPager: Bool
    ) -> some View {
        let pageItem = pagerState.pageItems[index]
        let isCurrentPage = self.isVisible && pageItem.identifier == pagerState.currentPageId

        VStack {
            ViewFactory.createView(
                pageItem.view,
                constraints: childConstraints
            )
            .airshipApplyIf(isLegacyPager) { view in
                view.allowsHitTesting(isCurrentPage)
            }
            .environment(\.isVisible, isCurrentPage)
            .environment(\.pageIdentifier, pageItem.identifier)
            .accessibilityActions {
                makeAccessibilityActions(pageItem: pageItem)
            }
            .accessibilityHidden(!isCurrentPage)
        }
        .airshipApplyIf(self.constraints.height == nil) { view in
            view.airshipMeasureView { newSize in
                if pageHeights[pageItem.identifier] != newSize.height {
                    pageHeights[pageItem.identifier] = newSize.height
                }
            }
        }
        .frame(
            width: width,
            height: height,
            alignment: .top
        )
        .environment(
            \.isButtonActionsEnabled,
             (!self.isLegacyPageSwipeEnabled || self.translation == 0)
        )
        .accessibilityElement(children: .contain)
        .id(pageItem.identifier)
    }

    @ViewBuilder
    private func makePageViews(
        childConstraints: ViewConstraints,
        width: CGFloat?,
        height: CGFloat?,
        isLegacyPager: Bool
    ) -> some View {
        ForEach(0..<pagerState.pageItems.count, id: \.self) { index in
            makePageView(
                for: index,
                childConstraints: childConstraints,
                width: width,
                height: height,
                isLegacyPager: isLegacyPager
            ).onAppear {
                if pagerState.pageItems[index].identifier == pagerState.currentPageId {
                    pagerState.confirmNavigation()
                }
            }
        }
    }

    @ViewBuilder
    private func makeAccessibilityActions(pageItem: ThomasViewInfo.Pager.Item) -> some View {
        if let actions = pageItem.accessibilityActions {
            ForEach(0..<actions.count, id: \.self) { i in
                let action = actions[i]
                Button {
                    handleEvents(.accessibilityAction(action))
                    self.process(action.preparedOutcomes())
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
            .airshipOnChangeOf(pagerState.completed) { completed in
                guard completed else { return }
                reportCompleted()
            }
            .airshipOnChangeOf(pagerState.currentPageId, initial: true) { pageID in
                guard let pageID else { return }

                reportPage(pageID: pageID)

                guard pageID != scrollPosition else { return }

                if scrollPosition != nil {
                    pagerState.disableTouchDuringNavigation()
                    withAnimation {
                        scrollPosition = pageID
                    }
                } else {
                    // Nil means the scroll view was just created or recreated (e.g. after
                    // rotation rebuilds via .id(verticalSizeClass)). Set directly without
                    // animation — animating from offset 0 sweeps intermediate pages and
                    // fires spurious navigateToPage calls via onChange(scrollPosition).
                    scrollPosition = pageID
                }
            }
            .airshipOnChangeOf(isVisible) { visible in
                if visible, let pageID = pagerState.currentPageId {
                    reportPage(pageID: pageID)
                }
                if visible, pagerState.completed {
                    reportCompleted()
                }
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
            .accessibilityElement(children: .contain)

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
                
                    self.process(gesture.outcomes ?? gesture.behavior?.makeOutcomes())
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
                    
                    self.process(gesture.outcomes ?? gesture.behavior?.makeOutcomes())
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
            if !isPressed {
                handleEvents(
                    .gesture(
                        identifier: gesture.identifier,
                        reportingMetadata: gesture.reportingMetadata
                    )
                )
            }
            
            let outcomes = if isPressed {
                gesture.pressOutcomes ?? gesture.pressBehavior?.makeOutcomes()
            } else {
                gesture.releaseOutcomes ?? gesture.releaseBehavior?.makeOutcomes()
            }
            
            self.process(outcomes)
        }
    }

    private func onTimer() {
        guard !isVoiceOverRunning,
              let automatedActions = self.pagerState.pageItems[self.pagerState.pageIndex].automatedActions
        else {
            return
        }

        let duration = self.pagerState.pageStates[pagerState.pageIndex].delay
        let safeDuration = (duration > 0 && duration.isFinite) ? duration : 1.0

        if self.pagerState.inProgress && (self.pagerState.pageIndex < pagerState.pageItems.count) {
            if (self.pagerState.progress < 1) {
                self.pagerState.progress += Pager.timerTransition / safeDuration
            }

            // Check for any automated action past the current duration that have not been executed yet
            automatedActions.filter {
                let isExecuted = (self.pagerState.currentPageState?.automatedActionStatus[$0.identifier] == true)
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

        self.process(automatedAction.preparedOutcomes())

        self.pagerState.markAutomatedActionExecuted(automatedAction.identifier)
    }

    private func process(_ outcomes: [ThomasOutcome]?) {
        guard let outcomes else { return }
        
        Task {
            await thomasState.process(
                outcomes: outcomes,
                actionsDelegate: { [weak thomasEnvironment, layoutState] outcome in
                    switch outcome {
                    case .formAction: break
                    case .dismiss(let outcome):
                        thomasEnvironment?.dismiss(cancel: outcome.cancel ?? false, layoutState: layoutState)
                    case .runAction(let outcome):
                        thomasEnvironment?.runActions(outcome.actions, layoutState: layoutState)
                    }
                }
            )
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

    private func reportCompleted() {
        guard isVisible, !hasReportedCompleted else { return }
        self.hasReportedCompleted = true
        self.thomasEnvironment.pagerCompleted(
            pagerState: pagerState,
            layoutState: layoutState
        )
    }

    private func reportPage(pageID: String) {
        guard
            isVisible,
            self.lastReportedPageID != pageID,
            let page = pagerState.pageItems.first(where: { $0.identifier == pageID })
        else {
            return
        }

        self.thomasEnvironment.pageViewed(
            pagerState: self.pagerState,
            pageInfo: self.pagerState.pageInfo(pageIdentifier: pageID),
            layoutState: layoutState
        )
        self.lastReportedPageID = pageID

        if isVoiceOverRunning {
            // Small delay to allow the UI to settle after navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
#if os(watchOS)
                // watchOS handles accessibility focus via the system pager automatically
#elseif os(macOS)
                // For macOS, notify that the layout has changed within the app
                NSAccessibility.post(
                    element: (NSApp.mainWindow ?? NSApp) as Any,
                    notification: .layoutChanged
                )
#else
                // For iOS, tvOS, and visionOS
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
#endif
            }
        }

        // Run any actions set on the current page
        self.process(page.preparedOutcomes())

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

extension ThomasAccessibilityAction {
    func preparedOutcomes() -> [ThomasOutcome] {
        if let outcomes = properties.outcomes { return outcomes }
        
        var result = properties.behaviors?.map(\.asOutcome) ?? []
        if let actions = properties.actions {
            let actionOutcomes = actions.enumerated().map { index, action in
                action.asOutcome(index: index)
            }
            result.append(contentsOf: actionOutcomes)
        }
        
        return result
    }
}

extension ThomasViewInfo.Pager.Gesture.GestureBehavior {
    func makeOutcomes() -> [ThomasOutcome] {
        let behaviors = behaviors?.map(\.asOutcome) ?? []
        let actions = actions?.enumerated().map { index, action in
            action.asOutcome(index: index)
        } ?? []
        
        return behaviors + actions
    }
}

extension ThomasAutomatedAction {
    func preparedOutcomes() -> [ThomasOutcome] {
        if let outcomes = outcomes { return outcomes }
        
        let behaviors = behaviors?.map(\.asOutcome) ?? []
        let actions = actions?.enumerated().map { index, action in
            action.asOutcome(index: index)
        } ?? []
        return behaviors + actions
    }
}

extension ThomasViewInfo.Pager.Item {
    func preparedOutcomes() -> [ThomasOutcome] {
        if let outcomes = displayOutcomes { return outcomes }
        
        var result: [ThomasOutcome] = stateActions?.map(\.asOutcome) ?? []
        
        if let actions = displayActions {
            result.append(actions.asOutcome())
        }
        
        return result
    }
}


