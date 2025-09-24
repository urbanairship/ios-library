/* Copyright Airship and Contributors */

public import SwiftUI
import AirshipCore
import AirshipPreferenceCenter


/// An enum that defines all possible navigation routes within the Airship debug interface.
///
/// `AirshipDebugRoute` provides type-safe navigation for the debug interface.
/// Each route case maps to a specific SwiftUI view through the `navigationDestination`
/// computed property, enabling seamless navigation between different debug sections.
///
/// ## Usage
///
/// Routes are used internally by the `AirshipDebugView` for navigation. The
/// `navigationDestination` property automatically resolves each route to its
/// corresponding SwiftUI view.
///
/// ## Route Categories
///
/// The routes are organized into main categories with optional sub-routes:
/// - **Privacy Manager**: Privacy settings and controls
/// - **Channel**: Channel management with sub-routes for tags, attributes, etc.
/// - **Contact**: Contact management with sub-routes for different channel types
/// - **Push**: Push notification management with sub-routes for details
/// - **Analytics**: Analytics data with sub-routes for events and identifiers
/// - **In-App Experience**: In-app experiences with sub-routes for automations and experiments
/// - **Feature Flags**: Feature flag management with sub-routes for details
/// - **Preference Centers**: Preference center management with sub-routes for specific centers
/// - **App Info**: General app and SDK information
///
/// - Note: This enum is thread-safe and can be used across different threads.
public enum AirshipDebugRoute: Sendable, Equatable, Hashable {
    /// Navigate to the privacy manager section.
    case privacyManager
    
    /// Navigate to the main channel section.
    case channel
    
    /// Navigate to a specific channel sub-section.
    case channelSub(ChannelRoute)
    
    /// Navigate to the main contact section.
    case contact
    
    /// Navigate to a specific contact sub-section.
    case contactSub(ContactRoute)
    
    /// Navigate to the main push notifications section.
    case push
    
    /// Navigate to a specific push notifications sub-section.
    case pushSub(PushRoute)
    
    /// Navigate to the main analytics section.
    case analytics
    
    /// Navigate to a specific analytics sub-section.
    case analyticsSub(AnalyticsRoute)
    
    /// Navigate to the main in-app experiences section.
    case inAppExperience
    
    /// Navigate to a specific in-app experiences sub-section.
    case inAppExperienceSub(InAppExperienceRoute)
    
    /// Navigate to the main feature flags section.
    case featureFlags
    
    /// Navigate to a specific feature flag sub-section.
    case featureFlagsSub(FeatureFlagRoute)
    
    /// Navigate to the main preference centers section.
    case preferenceCenters
    
    /// Navigate to a specific preference center sub-section.
    case preferenceCentersSub(PrefenceCenterRoute)
    
    /// Navigate to the app information section.
    case appInfo

    /// Sub-routes for the channel management section.
    public enum ChannelRoute: Sendable, Equatable, Hashable {
        /// Navigate to the channel tags management view.
        case tags
        
        /// Navigate to the channel tag groups management view.
        case tagGroups
        
        /// Navigate to the channel attributes management view.
        case attributes
        
        /// Navigate to the channel subscription lists management view.
        case subscriptionLists
    }

    /// Sub-routes for the contact management section.
    public enum ContactRoute: Sendable, Equatable, Hashable {
        /// Navigate to the contact tag groups management view.
        case tagGroups
        
        /// Navigate to the contact attributes management view.
        case attributes
        
        /// Navigate to the contact subscription lists management view.
        case subscriptionLists
        
        /// Navigate to the add open channel view.
        case addOpenChannel
        
        /// Navigate to the add SMS channel view.
        case addSMSChannel
        
        /// Navigate to the add email channel view.
        case addEmailChannel
        
        /// Navigate to the named user ID management view.
        case namedUserID
    }

    /// Sub-routes for the analytics section.
    public enum AnalyticsRoute: Sendable, Equatable, Hashable {
        /// Navigate to the analytics events list view.
        case events
        
        /// Navigate to the details view for a specific analytics event.
        /// - Parameter identifier: The unique identifier of the event to display.
        case eventDetails(identifier: String)
        
        /// Navigate to the add analytics event view.
        case addEvent
        
        /// Navigate to the associated identifiers management view.
        case associatedIdentifiers
    }

    /// Sub-routes for the in-app experiences section.
    public enum InAppExperienceRoute: Sendable, Equatable, Hashable {
        /// Navigate to the in-app automations view.
        case automations
        
        /// Navigate to the experiments view.
        case experiments
    }

    /// Sub-routes for the feature flags section.
    public enum FeatureFlagRoute: Sendable, Equatable, Hashable {
        /// Navigate to the details view for a specific feature flag.
        /// - Parameter name: The name of the feature flag to display.
        case featureFlagDetails(name: String)
    }

    /// Sub-routes for the preference centers section.
    public enum PrefenceCenterRoute: Sendable, Equatable, Hashable {
        /// Navigate to the details view for a specific preference center.
        /// - Parameter identifier: The identifier of the preference center to display.
        case preferenceCenter(identifier: String)
    }

    /// Sub-routes for the push notifications section.
    public enum PushRoute: Sendable, Equatable, Hashable {
        /// Navigate to the received push notifications list view.
        case recievedPushes
        
        /// Navigate to the details view for a specific push notification.
        /// - Parameter identifier: The unique identifier of the push notification to display.
        case pushDetails(identifier: String)
    }
}

public extension AirshipDebugRoute {
    /// Returns the SwiftUI view that corresponds to this route.
    ///
    /// This computed property provides the view that should be displayed when
    /// navigating to this route. It uses a switch statement to map each route
    /// case to its corresponding SwiftUI view.
    ///
    /// - Returns: The SwiftUI view that should be displayed for this route.
    @ViewBuilder
    @MainActor
    var navigationDestiation: some View {
        switch(self) {
        case .privacyManager: AirshipDebugPrivacyManagerView()
        case .channel: AirshipDebugChannelView()
        case .channelSub(let subRoute):
            switch(subRoute) {
            case .tags: AirshipDebugChannelTagView()
            case .attributes: AirshipDebugAttributesEditorView(for: .channel)
            case .subscriptionLists: AirshipDebugChannelSubscriptionsView()
            case .tagGroups: AirshipDebugTagGroupsEditorView(for: .channel)
            }

        case .contact: AirshipDebugContactsView()
        case .contactSub(let subRoute):
            switch(subRoute) {
            case .attributes: AirshipDebugAttributesEditorView(for: .contact)
            case .subscriptionLists: AirshipDebugContactSubscriptionEditorView()
            case .tagGroups: AirshipDebugTagGroupsEditorView(for: .contact)
            case .addSMSChannel: AirshipDebugAddSMSChannelView()
            case .addOpenChannel: AirshipDebugAddOpenChannelView()
            case .addEmailChannel: AirshipDebugAddEmailChannelView()
            case .namedUserID: AirshipDebugNamedUserView()
            }
            
        case .push: AirshipDebugPushView()
        case .pushSub(let subRoute):
            switch(subRoute) {
            case .recievedPushes: AirshipDebugReceivedPushView()
            case .pushDetails(let identifier): AirshipDebugPushDetailsView(identifier: identifier)
            }

        case .analytics: AirshipDebugAnalyticsView()
        case .analyticsSub(let subRoute):
            switch(subRoute) {
            case .associatedIdentifiers: AirshipDebugAnalyticIdentifierEditorView()
            case .events: AirshipDebugEventsView()
            case .addEvent: AirshipDebugAddEventView()
            case .eventDetails(let identifier): AirshipDebugEventDetailsView(identifier: identifier)
            }

        case .inAppExperience: AirshipDebugInAppExperiencesView()
        case .inAppExperienceSub(let subRoute):
            switch(subRoute) {
            case .experiments: AirshipDebugExperimentsView()
            case .automations: AirshipDebugAutomationsView()
            }
        case .featureFlags: AirshipDebugFeatureFlagView()
        case .featureFlagsSub(let subRoute):
            switch(subRoute) {
            case .featureFlagDetails(let name): AirshipDebugFeatureFlagDetailsView(name: name)
            }

        case .preferenceCenters: AirshipDebugPreferenceCentersView()
        case .preferenceCentersSub(let subRoute):
            switch(subRoute) {
            case .preferenceCenter(let identifier): AirshipDebugPreferencCenterItemView(preferenceCenterID: identifier)
            }

        case .appInfo: AirshipDebugAppInfoView()
        }
    }
}
