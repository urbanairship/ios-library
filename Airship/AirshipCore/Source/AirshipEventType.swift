/* Copyright Airship and Contributors */

import Foundation

/**
 * Airship event types
 */
public enum EventType: CaseIterable, Sendable, Equatable, Hashable {
    case appInit
    case appForeground
    case appBackground
    case screenTracking
    case associateIdentifiers
    case installAttribution
    case interactiveNotificationAction
    case pushReceived
    case deviceRegistration
    case regionEnter
    case regionExit
    case customEvent
    case featureFlagInteraction
    case inAppDisplay
    case inAppResolution
    case inAppButtonTap
    case inAppPermissionResult
    case inAppFormDisplay
    case inAppFormResult
    case inAppGesture
    case inAppPagerCompleted
    case inAppPagerSummary
    case inAppPageSwipe
    case inAppPageView
    case inAppPageAction

    /// NOTE: For internal use only. :nodoc:
    public var reportingName: String {
        switch self {
        case .appInit:
            return "app_init"
        case .appForeground:
            return "app_foreground"
        case .appBackground:
            return "app_background"
        case .screenTracking:
            return "screen_tracking"
        case .associateIdentifiers:
            return "associate_identifiers"
        case .installAttribution:
            return "install_attribution"
        case .interactiveNotificationAction:
            return "interactive_notification_action"
        case .pushReceived:
            return "push_received"
        case .deviceRegistration:
            return "device_registration"
        case .regionEnter, .regionExit:
            return "region_event"
        case .customEvent:
            return "enhanced_custom_event"
        case .featureFlagInteraction:
            return "feature_flag_interaction"
        case .inAppDisplay:
            return "in_app_display"
        case .inAppResolution:
            return "in_app_resolution"
        case .inAppButtonTap:
            return "in_app_button_tap"
        case .inAppPermissionResult:
            return "in_app_permission_result"
        case .inAppFormDisplay:
            return "in_app_form_display"
        case .inAppFormResult:
            return "in_app_form_result"
        case .inAppGesture:
            return "in_app_gesture"
        case .inAppPagerCompleted:
            return "in_app_pager_completed"
        case .inAppPagerSummary:
            return "in_app_pager_summary"
        case .inAppPageSwipe:
            return "in_app_page_swipe"
        case .inAppPageView:
            return "in_app_page_view"
        case .inAppPageAction:
            return "in_app_page_action"
        }
    }
}
