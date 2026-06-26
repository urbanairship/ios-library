/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ThomasEnvironment: ObservableObject {
    private let delegate: any ThomasDelegate
    private let pagerTracker: ThomasPagerTracker
    private let timer: any AirshipTimerProtocol
    private let stateStorage: (any ThomasStateStorage)?
    private var prefetchTokens: Set<String> = []

    private var state: [String: Any] = [:]

    func retrieveState<T: ThomasStateProvider>(identifier: String, create: () -> T) -> T {
        let key = "\(identifier):\(T.self)"
        if let existing = self.state[key] as? T {
            return existing
        }
        
        if let stored = stateStorage?.retrieve(identifier: key, builder: create) {
            self.state[key] = stored
            return stored
        }
        
        let new = create()
        state[key] = new
        stateStorage?.store(new, identifier: key)

        return new
    }

    @Published
    var isDismissed = false

    @Published
    var focusedID: String? = nil

    private var onDismiss: (() -> Void)?
    private var dismissHandle: ThomasDismissHandle?
    private var dismissCleanupHandlers: [ObjectIdentifier: () -> Void] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    @Published private(set) var keyboardState: KeyboardState = .hidden


    @MainActor
    init(
        delegate: any ThomasDelegate,
        pagerTracker: ThomasPagerTracker? = nil,
        timer: (any AirshipTimerProtocol)? = nil,
        stateStorage: (any ThomasStateStorage)? = nil,
        dismissHandle: ThomasDismissHandle? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.delegate = delegate
        self.pagerTracker = pagerTracker ?? ThomasPagerTracker()
        self.timer = timer ?? AirshipTimer()
        self.onDismiss = onDismiss
        self.stateStorage = stateStorage
        
        #if !os(tvOS) && !os(watchOS) && !os(macOS)
        self.subscribeKeyboard()
        #endif

        self.dismissHandle = dismissHandle
        dismissHandle?.addOnDismiss { [weak self] cancel in
            self?.dismiss(cancel: cancel)
        }
    }

    @MainActor
    func registerDismissCleanup(for owner: AnyObject, _ handler: @escaping () -> Void) {
        dismissCleanupHandlers[ObjectIdentifier(owner)] = handler
    }

    @MainActor
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {
        if isVisible, isForegrounded {
            timer.start()
        } else {
            timer.stop()
        }

        self.delegate.onVisibilityChanged(
            isVisible: isVisible,
            isForegrounded: isForegrounded
        )
    }

    @MainActor
    func submitForm(
        result: ThomasFormResult,
        channels: [ThomasFormField.Channel],
        attributes: [ThomasFormField.Attribute],
        layoutState: LayoutState
    ) {
        self.delegate.onReportingEvent(
            .formResult(
                .init(forms: result.formData),
                makeLayoutContext(layoutState: layoutState)
            )
        )

        self.delegate.applyAttributes(attributes)
        self.delegate.registerChannels(channels)
    }

    @MainActor
    func formDisplayed(_ formState: ThomasFormState, layoutState: LayoutState) {
        self.delegate.onReportingEvent(
            .formDisplay(
                .init(
                    identifier: formState.identifier,
                    formType: formState.formTypeString
                ),
                makeLayoutContext(layoutState: layoutState)
            )
        )
    }

    @MainActor
    func buttonTapped(
        buttonIdentifier: String,
        reportingMetadata: AirshipJSON?,
        layoutState: LayoutState
    ) {
        self.delegate.onReportingEvent(
            .buttonTap(
                .init(
                    identifier: buttonIdentifier,
                    reportingMetadata: reportingMetadata
                ),
                makeLayoutContext(layoutState: layoutState)
            )
        )
    }

    @MainActor
    func pageViewed(
        pagerState: PagerState,
        pageInfo: ThomasPageInfo,
        layoutState: LayoutState
    ) {
        let pageViewedEvent = ThomasReportingEvent.PageViewEvent(
            identifier: pagerState.identifier,
            pageIdentifier: pageInfo.identifier,
            pageIndex: pageInfo.index,
            pageViewCount: pageInfo.viewCount,
            pageCount: pagerState.reportingPageCount,
            completed: pagerState.completed
        )
        pagerTracker.onPageView(pageEvent: pageViewedEvent, currentDisplayTime: timer.time)
        self.delegate.onReportingEvent(
            .pageView(
                pageViewedEvent,
                makeLayoutContext(layoutState: layoutState)
            )
        )
    }

    @MainActor
    func pagerCompleted(
        pagerState: PagerState,
        layoutState: LayoutState
    ) {
        pagerTracker.markCompleted(pagerIdentifier: pagerState.identifier)
        self.delegate.onReportingEvent(
            .pagerCompleted(
                .init(
                    identifier: pagerState.identifier,
                    pageIndex: pagerState.pageIndex,
                    pageCount: pagerState.reportingPageCount,
                    pageIdentifier: pagerState.currentPageId ?? ""
                ),
                makeLayoutContext(layoutState: layoutState)
            )
        )
    }

    @MainActor
    func dismiss(
        buttonIdentifier: String,
        buttonDescription: String,
        cancel: Bool,
        layoutState: LayoutState
    ) {
        tryDismiss(layoutState: layoutState) { displayTime in
            self.delegate.onReportingEvent(
                .dismiss(
                    .buttonTapped(
                        identifier: buttonIdentifier,
                        description: buttonDescription
                    ),
                    displayTime,
                    makeLayoutContext(layoutState: layoutState)
                )
            )
            self.delegate.onDismissed(cancel: cancel)
        }
    }

    @MainActor
    func dismiss(cancel: Bool = false, layoutState: LayoutState? = nil) {
        tryDismiss(layoutState: layoutState) { displayTime in
            self.delegate.onReportingEvent(
                .dismiss(
                    .userDismissed,
                    displayTime,
                    makeLayoutContext(layoutState: layoutState)
                )
            )
            self.delegate.onDismissed(cancel: cancel)
        }
    }

    @MainActor
    func timedOut(layoutState: LayoutState? = nil) {
        tryDismiss(layoutState: layoutState) { displayTime in
            self.delegate.onReportingEvent(
                .dismiss(
                    .timedOut,
                    displayTime,
                    makeLayoutContext(layoutState: layoutState)
                )
            )
            self.delegate.onDismissed(cancel: false)
        }
    }
    
    @MainActor
    func pageGesture(
        identifier: String?,
        reportingMetadata: AirshipJSON?,
        layoutState: LayoutState
    ) {
        if let identifier {
            self.delegate.onReportingEvent(
                .gesture(
                    .init(
                        identifier: identifier,
                        reportingMetadata: reportingMetadata
                    ),
                    makeLayoutContext(layoutState: layoutState)
                )
            )
        }
    }
    
    @MainActor
    func pageAutomated(
        identifier: String?,
        reportingMetadata: AirshipJSON?,
        layoutState: LayoutState
    ) {
        if let identifier {
            self.delegate.onReportingEvent(
                .pageAction(
                    .init(
                        identifier: identifier,
                        reportingMetadata: reportingMetadata
                    ),
                    makeLayoutContext(layoutState: layoutState)
                )
            )
        }
    }
    
    @MainActor
    func pageSwiped(
        pagerState: PagerState,
        from: ThomasPageInfo,
        to: ThomasPageInfo,
        layoutState: LayoutState
    ) {
        self.delegate.onReportingEvent(
            .pageSwipe(
                .init(
                    identifier: pagerState.identifier,
                    toPageIndex: to.index,
                    toPageIdentifier: to.identifier,
                    fromPageIndex: from.index,
                    fromPageIdentifier: from.identifier
                ),
                makeLayoutContext(layoutState: layoutState)
            )
        )
    }

    @MainActor
    func onStateChange(_ state: AirshipJSON) {
        self.delegate.onStateChanged(state)
    }

    private func emitPagerSummaryEvents(layoutState: LayoutState?) {
        pagerTracker.summary.forEach { summary in
            delegate.onReportingEvent(
                .pagerSummary(
                    summary,
                    makeLayoutContext(layoutState: layoutState)
                )
            )
        }
    }

    @MainActor
    private func tryDismiss(
        layoutState: LayoutState? = nil,
        callback: (TimeInterval) -> Void
    ) {
        if !self.isDismissed {
            self.isDismissed = true

            timer.stop()

            pagerTracker.stopAll(currentDisplayTime: timer.time)
            emitPagerSummaryEvents(layoutState: layoutState)

            stateStorage?.flush()
            
            let cleanups = dismissCleanupHandlers.values
            dismissCleanupHandlers.removeAll()
            cleanups.forEach { $0() }

            let tokens = prefetchTokens
            prefetchTokens.removeAll()
            tokens.forEach { delegate.releasePrefetchedImages(token: $0) }

            callback(timer.time)
            onDismiss?()
            self.onDismiss = nil
        }
    }

    @MainActor
    func runActions(
        _ actionsPayload: ThomasActionsPayload?,
        layoutState: LayoutState?
    ) {
        guard let actions = actionsPayload?.value else { return }
        self.delegate.runActions(
            actions,
            layoutContext: makeLayoutContext(layoutState: layoutState)
        )
    }

#if !os(tvOS) && !os(watchOS)
    @MainActor
    func makeWebView(
        url: String,
        layoutState: LayoutState?,
        isLoading: Binding<Bool>,
        onClose: @escaping @MainActor () -> Void
    ) -> any View {
        self.delegate.makeWebView(
            url: url,
            layoutContext: makeLayoutContext(layoutState: layoutState),
            isLoading: isLoading,
            onClose: onClose
        )
    }
#endif

    @MainActor
    func loadImage(url: String) async throws -> AirshipImageData {
        try await delegate.loadImage(url: url)
    }

    /// Prefetches images for the layout. The environment owns the prefetched assets and releases
    /// them automatically when the layout dismisses.
    @MainActor
    func prefetch(images: [String]) async throws {
        guard !images.isEmpty else { return }
        if let token = try await delegate.prefetchImages(images) {
            prefetchTokens.insert(token)
        }
    }

    private func makeLayoutContext(layoutState: LayoutState?) -> ThomasLayoutContext {
        var context = ThomasLayoutContext()
        if let pager = layoutState?.pagerState {
            context.pager = .init(
                identifier: pager.identifier,
                pageIdentifier: pager.currentPageId ?? "",
                pageIndex: pager.pageIndex,
                completed: pager.completed,
                count: pager.reportingPageCount,
                pageHistory: pagerTracker.viewedPages(
                    pagerIdentifier: pager.identifier
                )
            )
        }

        if let form = layoutState?.formState {
            context.form = .init(
                identifier: form.identifier,
                submitted: form.status == .submitted,
                type: form.formTypeString,
                responseType: form.formResponseType
            )
        }

        if let form = layoutState?.buttonState {
            context.button = .init(
                identifier: form.identifier
            )
        }

        return context
    }

    #if !os(tvOS) && !os(watchOS) && !os(macOS)
    @MainActor
    private func subscribeKeyboard() {
        Publishers.Merge3(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardDidShowNotification)
                .map { _ in
                    return KeyboardState.visible
                },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { notification in
                    let duration =
                        notification.userInfo?[
                            UIResponder.keyboardAnimationDurationUserInfoKey
                        ] as? Double
                    return KeyboardState.displaying(duration ?? 0.25)
                },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardDidHideNotification)
                .map { _ in
                    return KeyboardState.hidden
                }
        )
        .removeDuplicates()
        .subscribe(on: DispatchQueue.main)
        .sink { [weak self] value in
            self?.keyboardState = value
        }
        .store(in: &self.subscriptions)
    }

    #endif
}


extension ThomasFormState {
    fileprivate var formTypeString: String {
        switch self.formType {
        case .form:
            return "form"
        case .nps(_):
            return "nps"
        }
    }
}

enum KeyboardState: Equatable {
    case hidden
    case displaying(Double)
    case visible
}
