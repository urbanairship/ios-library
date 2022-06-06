/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasDelegate)
public protocol ThomasDelegate {
    
    /// Called when a form is submitted
    /// - Parameters:
    ///     - formResult: The form result.
    ///     - layoutContext: The layout context.
    func onFormSubmitted(formResult: ThomasFormResult, layoutContext: ThomasLayoutContext)
    
    /// Called when a form is displayed for the first time
    /// - Parameters:
    ///     - formInfo: The form info.
    ///     - layoutContext: The layout context.
    func onFormDisplayed(formInfo: ThomasFormInfo, layoutContext: ThomasLayoutContext)
    
    /// Called when a button is tapped.
    /// - Parameters:
    ///     - buttonIdentifier: The button id.
    ///     - layoutContext: The layout context.
    func onButtonTapped(buttonIdentifier: String, layoutContext: ThomasLayoutContext)
    
    /// Called when the view is dismissed.
    /// - Parameters:
    ///     - layoutContext: The layout context.
    func onDismissed(layoutContext: ThomasLayoutContext?)
    
    /// Called when the view is dismissed from a button tap.
    /// - Parameters:
    ///     - buttonIdentifier: The  button id.
    ///     - buttonDescription: The button description.
    ///     - cancel: If the view should be cancelled.
    ///     - layoutContext: The layout context.
    func onDismissed(buttonIdentifier: String,
                     buttonDescription: String,
                     cancel: Bool,
                     layoutContext: ThomasLayoutContext)
    
    /// Called when a form is dismissed beceuse it timed out.
    /// - Parameters:
    ///     - layoutContext: The layout context.
    func onTimedOut(layoutContext: ThomasLayoutContext?)
    
    /// Called when a pager page is viewed.
    /// - Parameters:
    ///     - pagerInfo: The pager info.
    ///     - layoutContext: The layout context.
    func onPageViewed(pagerInfo: ThomasPagerInfo, layoutContext: ThomasLayoutContext)
    
    /// Called when a pager page changed due to a swipe.
    /// - Parameters:
    ///     - from: The originated pager info
    ///     - to: The resulting pager info
    ///     - layoutContext: The layout context.
    func onPageSwiped(from: ThomasPagerInfo,
                      to: ThomasPagerInfo,
                      layoutContext: ThomasLayoutContext)

    /// Called when actions should be ran.
    /// - Parameters:
    ///     - actions: The actions.
    ///     - layoutContext: The layout context.
    func onRunActions(actions: [String : Any], layoutContext: ThomasLayoutContext)
}

/// - Note: for internal use only.  :nodoc:
@objc(UAThomasPagerInfo)
public class ThomasPagerInfo : NSObject {
    
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
    public init(identifier: String, pageIndex: Int, pageIdentifier: String, pageCount: Int, completed: Bool) {
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
public class ThomasFormResult : NSObject {
    @objc
    public let identifier: String
    
    @objc
    public let formData: [String : Any]
    
    @objc
    public init(identifier: String, formData: [String : Any]) {
        self.identifier = identifier
        self.formData = formData
    }

    public override var description: String {
        "ThomasFormResult{identifier=\(identifier), formData=\(formData)}"
    }
}


/// - Note: for internal use only.  :nodoc:
@objc(UAThomasButtonInfo)
public class ThomasButtonInfo : NSObject {
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
public class ThomasFormInfo : NSObject {
    @objc
    public let identifier: String
    
    @objc
    public let submitted: Bool
    
    @objc
    public let formType: String
    
    @objc
    public let formResponseType: String?
    
    @objc
    public init(identifier: String, submitted: Bool, formType: String, formResponseType: String?) {
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
public class ThomasLayoutContext : NSObject {
    @objc
    public let formInfo: ThomasFormInfo?
    
    @objc
    public let pagerInfo: ThomasPagerInfo?

    @objc
    public let buttonInfo: ThomasButtonInfo?

    @objc
    public init(formInfo: ThomasFormInfo?, pagerInfo: ThomasPagerInfo?, buttonInfo: ThomasButtonInfo?) {
        self.formInfo = formInfo
        self.pagerInfo = pagerInfo
        self.buttonInfo = buttonInfo
    }

    public override var description: String {
        "ThomasLayoutContext{formInfo=\(String(describing: formInfo)), pagerInfo=\(String(describing: pagerInfo)), buttonInfo=\(String(describing: buttonInfo))}"
    }
}
