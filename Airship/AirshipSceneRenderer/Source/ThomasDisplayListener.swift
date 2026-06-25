import Foundation
public import SwiftUI
public import AirshipBasement
public import AirshipCore

/// - Note: For internal use only. :nodoc:
public protocol ThomasLayoutMessageAnalyticsProtocol: AnyObject, Sendable {
    @MainActor
    func recordEvent(
        _ event: any ThomasLayoutEvent,
        layoutContext: ThomasLayoutContext?
    )
}

@MainActor
@_spi(AirshipInternal)
public final class ThomasDisplayListener: ThomasDelegate {
    
    /// - Note: For internal use only. :nodoc:
    public enum DisplayResult: Sendable, Equatable {
        case cancel
        case finished
    }
    
    private let analytics: any ThomasLayoutMessageAnalyticsProtocol
    private var onDismiss: (@MainActor @Sendable (DisplayResult) -> Void)?
    private let actionRunner: (any ThomasActionRunner)?
#if !os(tvOS) && !os(watchOS)
    private let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?

    public init(
        analytics: any ThomasLayoutMessageAnalyticsProtocol,
        actionRunner: (any ThomasActionRunner)? = nil,
        nativeBridgeExtension: (any NativeBridgeExtensionDelegate)? = nil,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.actionRunner = actionRunner
        self.nativeBridgeExtension = nativeBridgeExtension
        self.onDismiss = onDismiss
    }
#else
    public init(
        analytics: any ThomasLayoutMessageAnalyticsProtocol,
        actionRunner: (any ThomasActionRunner)? = nil,
        onDismiss: @escaping @MainActor @Sendable (DisplayResult) -> Void
    ) {
        self.analytics = analytics
        self.actionRunner = actionRunner
        self.onDismiss = onDismiss
    }
#endif

    public func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {
        if isVisible, isForegrounded {
            analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        }
    }

    public func onReportingEvent(_ event: ThomasReportingEvent) {
        switch(event) {
        case .buttonTap(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutButtonTapEvent(data: event),
                layoutContext: layoutContext
            )
        case .formDisplay(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutFormDisplayEvent(data: event),
                layoutContext: layoutContext
            )
        case .formResult(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutFormResultEvent(data: event),
                layoutContext: layoutContext
            )
        case .gesture(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutGestureEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageAction(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageActionEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerCompleted(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPagerCompletedEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageSwipe(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageSwipeEvent(data: event),
                layoutContext: layoutContext
            )
        case .pageView(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPageViewEvent(data: event),
                layoutContext: layoutContext
            )
        case .pagerSummary(let event, let layoutContext):
            analytics.recordEvent(
                ThomasLayoutPagerSummaryEvent(data: event),
                layoutContext: layoutContext
            )
        case .dismiss(let event, let displayTime, let layoutContext):
            switch(event) {
            case .buttonTapped(identifier: let identifier, description: let description):
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.buttonTap(
                        identifier: identifier,
                        description: description,
                        displayTime: displayTime
                    ),
                    layoutContext: layoutContext
                )
            case .timedOut:
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.timedOut(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            case .userDismissed:
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            @unknown default:
                AirshipLogger.error("Unhandled dismiss type event \(event)")
                analytics.recordEvent(
                    ThomasLayoutResolutionEvent.userDismissed(displayTime: displayTime),
                    layoutContext: layoutContext
                )
            }


        @unknown default: AirshipLogger.error("Unhandled Native reporting event \(event)")
        }
    }

    public func onDismissed(cancel: Bool) {
        self.onDismiss?(cancel ? .cancel : .finished)
        self.onDismiss = nil
    }

    public func runActions(_ actions: AirshipJSON, layoutContext: ThomasLayoutContext) {
        guard let actionRunner else {
            Task {
                await ActionRunner.run(
                    actionsPayload: actions,
                    situation: .automation,
                    metadata: [:]
                )
            }
            return
        }
        actionRunner.runAsync(actions: actions, layoutContext: layoutContext)
    }

#if !os(tvOS) && !os(watchOS)
    public func makeWebView(
        url: String,
        layoutContext: ThomasLayoutContext,
        isLoading: Binding<Bool>,
        onClose: @escaping @MainActor () -> Void
    ) -> any View {
        AirshipThomasWebView(
            url: url,
            layoutContext: layoutContext,
            actionRunner: actionRunner,
            nativeBridgeExtension: nativeBridgeExtension,
            isLoading: isLoading,
            onClose: onClose
        )
    }
#endif

    public func registerChannels(_ channels: [ThomasChannelRegistration]) {
        channels.forEach { channelRegistration in
            switch channelRegistration {
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

    public func applyAttributes(_ attributes: [ThomasAttribute]) {
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
