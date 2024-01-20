/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasDelegate)
public protocol ThomasDelegate: Sendable {

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
        metadata: Any?,
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
        metadata: Any?,
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
        metadata: Any?,
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
@objc(UAThomasPagerInfo)
public final class ThomasPagerInfo: NSObject, Sendable {

    @objc
    public let identifier: String
    @objc
    public let pageIndex: Int

    @objc
    public let pageIdentifier: String

    @objc
    public let pageCount: Int

    @objc
    public let completed: Bool

    @objc
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

    public override var description: String {
        "ThomasPagerInfo{identifier=\(identifier), pageIndex=\(pageIndex)}, pageIdentifier=\(pageIdentifier), pageCount=\(pageCount), completed=\(completed)}"
    }
}

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasFormResult)
public class ThomasFormResult: NSObject {
    @objc
    public let identifier: String

    @objc
    public let formData: [String: Any]

    @objc
    public init(identifier: String, formData: [String: Any]) {
        self.identifier = identifier
        self.formData = formData
    }

    public override var description: String {
        "ThomasFormResult{identifier=\(identifier), formData=\(formData)}"
    }
}

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasButtonInfo)
public final class ThomasButtonInfo: NSObject, Sendable {
    @objc
    public let identifier: String

    @objc
    public init(identifier: String) {
        self.identifier = identifier
    }

    public override var description: String {
        "ThomasButtonInfo{identifier=\(identifier)}"
    }
}

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasFormInfo)
public final class ThomasFormInfo: NSObject, Sendable {
    @objc
    public let identifier: String

    @objc
    public let submitted: Bool

    @objc
    public let formType: String

    @objc
    public let formResponseType: String?

    @objc
    public init(
        identifier: String,
        submitted: Bool,
        formType: String,
        formResponseType: String?
    ) {
        self.identifier = identifier
        self.submitted = submitted
        self.formType = formType
        self.formResponseType = formResponseType
    }

    public override var description: String {
        "ThomasFormInfo{identifier=\(identifier), submitted=\(submitted), formType=\(formType), formResponseType=\(formResponseType ?? "")}"
    }
}

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasLayoutContext)
public final class ThomasLayoutContext: NSObject, Sendable {
    @objc
    public let formInfo: ThomasFormInfo?

    @objc
    public let pagerInfo: ThomasPagerInfo?

    @objc
    public let buttonInfo: ThomasButtonInfo?

    @objc
    public init(
        formInfo: ThomasFormInfo?,
        pagerInfo: ThomasPagerInfo?,
        buttonInfo: ThomasButtonInfo?
    ) {
        self.formInfo = formInfo
        self.pagerInfo = pagerInfo
        self.buttonInfo = buttonInfo
    }

    public override var description: String {
        "ThomasLayoutContext{formInfo=\(String(describing: formInfo)), pagerInfo=\(String(describing: pagerInfo)), buttonInfo=\(String(describing: buttonInfo))}"
    }
}
