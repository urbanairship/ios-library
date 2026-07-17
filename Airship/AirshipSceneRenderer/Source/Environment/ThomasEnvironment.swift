/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ThomasEnvironment: ObservableObject {
    private let delegate: any ThomasDelegate
    private let pagerTracker: ThomasPagerTracker
    private let timer: any AirshipTimerProtocol
    private let stateStorage: (any ThomasStateStorage)?

    /// Loads and prefetches images for this layout, sourced from `extensions`. The environment
    /// doesn't track tokens — the loader owns what it prefetched and releases it on dismiss.
    var imageLoader: any ThomasImageLoader { extensions.imageLoader }

    /// The window scene this layout is presented in, captured by the host at display time.
    /// Exposes orientation / status bar style without a global scene lookup; holds the scene
    /// weakly internally so a disconnected scene falls back to defaults.
    let windowScene: ThomasWindowScene

    /// Host-provided capabilities the renderer consumes. Carried here (rather than on the SwiftUI
    /// environment) so every view — including wrappers that sit *above* `RootView` — reaches the
    /// same factory by holding the environment, instead of resolving `@Environment` at their own
    /// (often wrong) position in the tree.
    let extensions: any ThomasExtensions

    /// View factory built from `extensions`. The single source of truth for inflating child views;
    /// reach it via the environment (`thomasEnvironment.viewFactory`), never the SwiftUI environment.
    var viewFactory: ViewFactory {
        ViewFactory(extensions: extensions)
    }

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
    var isDismissed: Bool = false

    @Published
    var focusedID: String? = nil

    /// Bumped to ask any focused layout text input to resign. SwiftUI does not resign
    /// first responder when a `Button` is tapped, so buttons bump this on tap — clearing
    /// focus at the SwiftUI `@FocusState` level (not just UIKit) keeps the two in sync so
    /// a later re-layout can't re-assert focus and trigger keyboard-avoidance snap-back.
    /// Scoped to this layout's inputs, so an embedded pager never drops the host keyboard.
    @Published
    var keyboardDismissRequest: Int = 0

    @MainActor
    func requestKeyboardDismiss() {
        keyboardDismissRequest &+= 1
    }

    private var onDismiss: (() -> Void)?
    private var dismissHandle: ThomasDismissHandle?
    private var dismissCleanupHandlers: [ObjectIdentifier: () -> Void] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    @Published private(set) var keyboardState: KeyboardState = .hidden


    @MainActor
    init(
        delegate: any ThomasDelegate,
        windowScene: ThomasWindowScene = ThomasWindowScene(),
        extensions: any ThomasExtensions,
        pagerTracker: ThomasPagerTracker? = nil,
        timer: (any AirshipTimerProtocol)? = nil,
        stateStorage: (any ThomasStateStorage)? = nil,
        dismissHandle: ThomasDismissHandle? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.delegate = delegate
        self.windowScene = windowScene
        self.extensions = extensions
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

        self.extensions.audienceEditor.applyAttributes(attributes)
        self.extensions.audienceEditor.registerChannels(channels)
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

    @MainActor
    func localizedString(key: String) -> String? {
        extensions.localizer.localizedString(key: key)
    }

    @MainActor
    func localizedString(key: String, fallback: String) -> String {
        localizedString(key: key) ?? fallback
    }

    @MainActor
    func resolveLocalized(_ localized: ThomasAccessibleInfo.Localized) -> String {
        if let refs = localized.refs {
            for ref in refs {
                if let string = localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = localized.ref {
            if let string = localizedString(key: ref) {
                return string
            }
        }

        return localized.fallback
    }

    @MainActor
    func resolveContentDescription(for accessible: ThomasAccessibleInfo) -> String? {
        if let contentDescription = accessible.contentDescription {
            return contentDescription
        }

        guard let localized = accessible.localizedContentDescription else {
            return nil
        }

        return resolveLocalized(localized)
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

            imageLoader.releaseAll()

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
        self.extensions.actionRunner.runAsync(
            actions: actions,
            layoutContext: makeLayoutContext(layoutState: layoutState)
        )
    }

    func makeLayoutContext(layoutState: LayoutState?) -> ThomasLayoutContext {
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
