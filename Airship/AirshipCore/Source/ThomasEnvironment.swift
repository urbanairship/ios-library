/* Copyright Airship and Contributors */

import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ThomasEnvironment: ObservableObject {
    private let delegate: any ThomasDelegate
    private let pagerTracker: ThomasPagerTracker
    private let timer: any AirshipTimerProtocol
    let extensions: ThomasExtensions?
    let imageLoader: AirshipImageLoader

    let defaultFormState = ThomasFormState(
        identifier: "",
        formType: .form,
        formResponseType: "",
        validationMode: .immediate
    )

    let defaultPagerState = PagerState(
        identifier: "",
        branching: nil
    )
    let defaultMutableState = ThomasState.MutableState()

    private var state: [String: Any] = [:]

    func retrieveState<T: ObservableObject>(identifier: String, create: () -> T) -> T {
        let key = "\(identifier):\(T.self)"
        guard let existing = self.state[key] as? T else {
            let new = create()
            state[key] = new
            return new
        }
        return existing
    }

    @Published
    var isDismissed = false

    @Published
    var focusedID: String? = nil

    private var onDismiss: (() -> Void)?

    private var subscriptions: Set<AnyCancellable> = Set()

    @Published private(set) var keyboardState: KeyboardState = .hidden

    @MainActor
    init(
        delegate: any ThomasDelegate,
        extensions: ThomasExtensions?,
        pagerTracker: ThomasPagerTracker = ThomasPagerTracker(),
        timer: any AirshipTimerProtocol = AirshipTimer(),
        onDismiss: (() -> Void)? = nil
    ) {
        self.delegate = delegate
        self.extensions = extensions
        self.pagerTracker = pagerTracker
        self.timer = timer
        self.onDismiss = onDismiss
        self.imageLoader = AirshipImageLoader(
            imageProvider: extensions?.imageProvider
        )
        #if !os(tvOS) && !os(watchOS)
        self.subscribeKeyboard()
        #endif
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

        applyAttributes(attributes)
        registerChannels(channels)
    }

    private func registerChannels(
        _ channels: [ThomasFormField.Channel]
    ) {
        channels.forEach { channelRegistration in
            switch(channelRegistration) {
            case .email(let address, let options):
                Airship.contact.registerEmail(
                    address,
                    options: options.makeContactOptions()
                )
            case .sms(let address, let options):
                Airship.contact.registerSMS(
                    address,
                    options: options.makeContactOptions()
                )
            }
            
        }
    }

    private func applyAttributes(
        _ attributes: [ThomasFormField.Attribute]
    ) {
        guard !attributes.isEmpty else { return }
        let channelEditor = Airship.channel.editAttributes()
        let contactEditor = Airship.contact.editAttributes()

        attributes.forEach { attribute in

            if let name = attribute.attributeName.channel {
                channelEditor.set(
                    attributeValue: attribute.attributeValue,
                    attribute: name
                )
            }

            if let name = attribute.attributeName.contact {
                contactEditor.set(
                    attributeValue: attribute.attributeValue,
                    attribute: name
                )
            }
        }

        channelEditor.apply()
        contactEditor.apply()
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
        tryDismiss { displayTime in
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
        tryDismiss { displayTime in
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
        tryDismiss { displayTime in
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
    private func tryDismiss(callback: (TimeInterval) -> Void) {
        if !self.isDismissed {
            self.isDismissed = true

            timer.stop()
            pagerTracker.stopAll(currentDisplayTime: timer.time)

            // Todo emit pager summary

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
        guard let actionsPayload = actionsPayload?.value else { return }
        guard let runner = extensions?.actionRunner else {
            Task {
                await ActionRunner.run(actionsPayload: actionsPayload, situation: .automation, metadata: [:])
            }
            return
        }

        runner.runAsync(
            actions: actionsPayload,
            layoutContext: makeLayoutContext(layoutState: layoutState)
        )
    }

    @MainActor
    func runAction(
        _ actionName: String,
        arguments: ActionArguments,
        layoutState: LayoutState?
    ) async -> ActionResult {
        guard let runner = extensions?.actionRunner else {
            return await ActionRunner.run(actionName: actionName, arguments: arguments)
        }

        return await runner.run(
            actionName: actionName,
            arguments: arguments,
            layoutContext: makeLayoutContext(layoutState: layoutState)
        )
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

    #if !os(tvOS) && !os(watchOS)
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

extension AttributesEditor {
    fileprivate func set(
        attributeValue: ThomasAttributeValue,
        attribute: String
    ) {
        switch attributeValue {
        case .string(let value):
            self.set(string: value, attribute: attribute)

        case .number(let value):
            self.set(double: value, attribute: attribute)
        }
    }
}

enum KeyboardState: Equatable {
    case hidden
    case displaying(Double)
    case visible
}
