/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// - Note: for internal use only.  :nodoc:
public protocol ThomasDelegate: Sendable {

    /// Called whenever the view appears
    @MainActor
    func onVisbilityChanged(isVisible: Bool, isForegrounded: Bool)

    /// Called when a form is submitted
    /// - Parameters:
    ///     - formResult: The form result.
    ///     - layoutContext: The layout context.
    @MainActor
    func onFormSubmitted(
        formResult: ThomasFormResult,
        layoutContext: ThomasLayoutContext
    )

    /// Called when a form is displayed for the first time
    /// - Parameters:
    ///     - formInfo: The form info.
    ///     - layoutContext: The layout context.
    @MainActor
    func onFormDisplayed(
        formInfo: ThomasFormInfo,
        layoutContext: ThomasLayoutContext
    )

    /// Called when a button is tapped.
    /// - Parameters:
    ///     - buttonIdentifier: The button id.
    ///     - metadata: the reporting metadata.
    ///     - layoutContext: The layout context.
    @MainActor
    func onButtonTapped(
        buttonIdentifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    )

    /// Called when the view is dismissed.
    /// - Parameters:
    ///     - layoutContext: The layout context.
    @MainActor
    func onDismissed(layoutContext: ThomasLayoutContext?)

    /// Called when the view is dismissed from a button tap.
    /// - Parameters:
    ///     - buttonIdentifier: The  button id.
    ///     - buttonDescription: The button description.
    ///     - cancel: If the view should be cancelled.
    ///     - layoutContext: The layout context.
    @MainActor
    func onDismissed(
        buttonIdentifier: String,
        buttonDescription: String,
        cancel: Bool,
        layoutContext: ThomasLayoutContext
    )

    /// Called when a form is dismissed because it timed out.
    /// - Parameters:
    ///     - layoutContext: The layout context.
    @MainActor
    func onTimedOut(layoutContext: ThomasLayoutContext?)

    /// Called when a pager page is viewed.
    /// - Parameters:
    ///     - pagerInfo: The pager info.
    ///     - layoutContext: The layout context.
    @MainActor
    func onPageViewed(
        pagerInfo: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    )

    /// Called when a pager page has a gesture.
    /// - Parameters:
    ///     - identifier: The pager gesture identifier.
    ///     - metadata: the reporting metadata.
    ///     - layoutContext: The layout context.
    @MainActor
    func onPageGesture(
        identifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    )

    /// Called when a pager page changed automatically after a delay.
    /// - Parameters:
    ///     - identifier: The automated action identifier.
    ///     - metadata: the reporting metadata.
    ///     - layoutContext: The layout context.
    @MainActor
    func onPageAutomatedAction(
        identifier: String,
        metadata: AirshipJSON?,
        layoutContext: ThomasLayoutContext
    )
    
    /// Called when a pager page changed due to a swipe.
    /// - Parameters:
    ///     - from: The originated pager info
    ///     - to: The resulting pager info
    ///     - layoutContext: The layout context.
    @MainActor
    func onPageSwiped(
        from: ThomasPagerInfo,
        to: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    )


    /// Called when actions should be ran.
    /// - Parameters:
    ///     - permission: The permission.
    ///     - startingStatus: The starting status.
    ///     - endingStatus: The ending status.
    ///     - layoutContext: The layout context.
    @MainActor
    func onPromptPermissionResult(
        permission: AirshipPermission,
        startingStatus: AirshipPermissionStatus,
        endingStatus: AirshipPermissionStatus,
        layoutContext: ThomasLayoutContext
    )
}

/// - Note: for internal use only.  :nodoc:
public struct ThomasPagerInfo: Sendable, Hashable, Equatable {
    public var identifier: String
    public var pageIndex: Int
    public var pageIdentifier: String
    public var pageCount: Int
    public var completed: Bool

    public init(
        identifier: String,
        pageIndex: Int,
        pageIdentifier: String,
        pageCount: Int,
        completed: Bool
    ) {
        self.identifier = identifier
        self.pageIndex = pageIndex
        self.pageIdentifier = pageIdentifier
        self.pageCount = pageCount
        self.completed = completed
    }
}

/// - Note: for internal use only.  :nodoc:
public struct ThomasFormResult: Sendable, Hashable, Equatable {
    public var identifier: String
    public var formData: AirshipJSON

    public init(identifier: String, formData: AirshipJSON) {
        self.identifier = identifier
        self.formData = formData
    }
}

/// - Note: for internal use only.  :nodoc:
public struct ThomasButtonInfo: Sendable, Hashable, Equatable {
    public var identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

/// - Note: for internal use only.  :nodoc:
public struct ThomasFormInfo: Sendable, Hashable, Equatable {
    public var identifier: String
    public var submitted: Bool
    public var formType: String
    public var formResponseType: String?

    public init(
        identifier: String,
        submitted: Bool,
        formType: String,
        formResponseType: String? = nil
    ) {
        self.identifier = identifier
        self.submitted = submitted
        self.formType = formType
        self.formResponseType = formResponseType
    }
}

/// - Note: for internal use only.  :nodoc:
public struct ThomasLayoutContext: Sendable, Hashable, Equatable {
    public var formInfo: ThomasFormInfo?
    public var pagerInfo: ThomasPagerInfo?
    public var buttonInfo: ThomasButtonInfo?

    public init(
        formInfo: ThomasFormInfo?,
        pagerInfo: ThomasPagerInfo?,
        buttonInfo: ThomasButtonInfo?
    ) {
        self.formInfo = formInfo
        self.pagerInfo = pagerInfo
        self.buttonInfo = buttonInfo
    }
}
